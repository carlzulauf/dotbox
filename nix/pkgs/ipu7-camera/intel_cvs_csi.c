// SPDX-License-Identifier: GPL-2.0-only
/*
 * CSI-2 pass-through sub-device for the Intel CVS vision coprocessor.
 *
 * Since commit c6b1b34b5090 ("media: pci: intel: Add CVS support for IPU
 * bridge driver") the kernel splices the CVS into the camera fwnode graph
 * between the sensor and the IPU:
 *
 *	OVTI02C1-0/port@0/endpoint@0 -> INTC10DE-0/port@0/endpoint@0
 *	INTC10DE-0/port@1/endpoint@0 -> INT343E/port@0/endpoint@0
 *
 * ipu-bridge attaches the INTC10DE-0 software node as the secondary fwnode of
 * whichever device it found for the CVS -- for an I2C CVS, this driver's own
 * i2c client -- and then ipu7-isys waits for a v4l2 sub-device to show up at
 * INTC10DE-0/port@1/endpoint@0.  Nothing upstream provides one for an I2C
 * CVS: drivers/media/pci/intel/ivsc only covers the MEI transport.  Without
 * it the notifier never completes, the sensor is never bound into the graph,
 * and libcamera reports "No sensor found".
 *
 * This is that missing sub-device.  The CVS passes the CSI-2 lanes through
 * untouched, so the sub-device only has to be a well-behaved pass-through:
 * mirror formats from sink to source, and switch sensor ownership from the
 * coprocessor to the host around streaming.  Doing the ownership handover in
 * .s_stream is what makes the privacy LED -- hard-wired to the CVS req GPIO
 * -- track actual camera use.
 *
 * Modelled on drivers/media/pci/intel/ivsc/mei_csi.c.
 *
 * Copyright (C) 2026 Intel Corporation.
 */

#include <linux/device.h>
#include <linux/intel_cvs.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/property.h>
#include <linux/workqueue.h>

#include <media/v4l2-async.h>
#include <media/v4l2-common.h>
#include <media/v4l2-fwnode.h>
#include <media/v4l2-subdev.h>

#include "intel_cvs_update.h"

#define CVS_CSI_ENTITY_NAME "Intel CVS CSI"

/*
 * ipu-bridge only builds the graph from intel_ipu7's probe, which defers
 * until this driver's device exists -- so our own probe always runs first and
 * the secondary fwnode is not there yet.  Poll for it rather than deferring
 * the whole CVS probe, which would leave the sensor unusable.
 */
#define CVS_CSI_POLL_MS 250
#define CVS_CSI_POLL_TRIES 120

enum cvs_csi_pad {
	CVS_CSI_PAD_SINK,
	CVS_CSI_PAD_SOURCE,
	CVS_CSI_NUM_PADS,
};

struct cvs_csi {
	struct device *dev;

	struct v4l2_subdev subdev;
	struct media_pad pads[CVS_CSI_NUM_PADS];
	struct media_pad *remote;
	struct v4l2_async_notifier notifier;

	/* Backs subdev.state_lock; taken by the v4l2 core around state ops. */
	struct mutex lock;
	/* Serialises .s_stream against itself.  Never nested in @lock. */
	struct mutex stream_lock;

	struct delayed_work bringup;
	unsigned int tries;
	bool registered;

	int streaming;
	u32 nr_of_lanes;
	u64 link_freq;
};

/* There is exactly one CVS on these machines. */
static struct cvs_csi *cvs_csi;

static const struct v4l2_mbus_framefmt cvs_csi_format_mbus_default = {
	.width = 1,
	.height = 1,
	.code = MEDIA_BUS_FMT_Y8_1X8,
	.field = V4L2_FIELD_NONE,
};

static inline struct cvs_csi *notifier_to_csi(struct v4l2_async_notifier *n)
{
	return container_of(n, struct cvs_csi, notifier);
}

static inline struct cvs_csi *sd_to_csi(struct v4l2_subdev *sd)
{
	return container_of(sd, struct cvs_csi, subdev);
}

static int cvs_csi_set_stream(struct v4l2_subdev *sd, int enable)
{
	struct cvs_csi *csi = sd_to_csi(sd);
	struct v4l2_subdev *remote_sd;
	int ret = 0;
	s64 freq;

	if (!csi->remote)
		return -ENOLINK;

	remote_sd = media_entity_to_v4l2_subdev(csi->remote->entity);

	mutex_lock(&csi->stream_lock);

	if (enable && csi->streaming == 0) {
		freq = v4l2_get_link_freq(csi->remote, 0, 0);
		if (freq < 0) {
			dev_err(csi->dev, "invalid link_freq %lld\n", freq);
			ret = freq;
			goto out;
		}
		csi->link_freq = freq;

		/*
		 * Take the sensor from the coprocessor.  Until this succeeds
		 * the sensor does not answer on I2C, so it has to happen
		 * before the sensor's own .s_stream touches the bus.
		 */
		ret = cvs_acquire_camera_sensor_internal();
		if (ret) {
			dev_err(csi->dev, "cannot take the sensor: %d\n", ret);
			goto out;
		}

		ret = v4l2_subdev_call(remote_sd, video, s_stream, 1);
		if (ret) {
			cvs_release_camera_sensor_internal();
			goto out;
		}

		csi->streaming = 1;
	} else if (!enable && csi->streaming == 1) {
		v4l2_subdev_call(remote_sd, video, s_stream, 0);

		ret = cvs_release_camera_sensor_internal();
		if (ret)
			dev_warn(csi->dev, "cannot hand the sensor back: %d\n",
				 ret);

		csi->streaming = 0;
	}

out:
	mutex_unlock(&csi->stream_lock);

	return ret;
}

static int cvs_csi_init_state(struct v4l2_subdev *sd,
			      struct v4l2_subdev_state *sd_state)
{
	struct v4l2_mbus_framefmt *mbusformat;
	unsigned int i;

	for (i = 0; i < sd->entity.num_pads; i++) {
		mbusformat = v4l2_subdev_state_get_format(sd_state, i);
		*mbusformat = cvs_csi_format_mbus_default;
	}

	return 0;
}

/* The CVS does not touch the data, so the source pad always mirrors the sink. */
static int cvs_csi_set_fmt(struct v4l2_subdev *sd,
			   struct v4l2_subdev_state *sd_state,
			   struct v4l2_subdev_format *format)
{
	struct v4l2_mbus_framefmt *source_fmt;
	struct v4l2_mbus_framefmt *sink_fmt;

	sink_fmt = v4l2_subdev_state_get_format(sd_state, CVS_CSI_PAD_SINK);
	source_fmt = v4l2_subdev_state_get_format(sd_state, CVS_CSI_PAD_SOURCE);

	if (format->pad == CVS_CSI_PAD_SOURCE) {
		*source_fmt = *sink_fmt;
		format->format = *source_fmt;

		return 0;
	}

	v4l_bound_align_image(&format->format.width, 1, 65536, 0,
			      &format->format.height, 1, 65536, 0, 0);
	format->format.field = V4L2_FIELD_NONE;

	*sink_fmt = format->format;
	*source_fmt = *sink_fmt;

	return 0;
}

static int cvs_csi_get_mbus_config(struct v4l2_subdev *sd, unsigned int pad,
				   struct v4l2_mbus_config *mbus_config)
{
	struct cvs_csi *csi = sd_to_csi(sd);
	unsigned int i;
	s64 freq;

	if (!csi->remote)
		return -ENOLINK;

	mbus_config->type = V4L2_MBUS_CSI2_DPHY;
	for (i = 0; i < V4L2_MBUS_CSI2_MAX_DATA_LANES; i++)
		mbus_config->bus.mipi_csi2.data_lanes[i] = i + 1;
	mbus_config->bus.mipi_csi2.num_data_lanes = csi->nr_of_lanes;

	freq = v4l2_get_link_freq(csi->remote, 0, 0);
	if (freq < 0) {
		dev_err(csi->dev, "invalid link_freq %lld\n", freq);
		return -EINVAL;
	}

	csi->link_freq = freq;
	mbus_config->link_freq = freq;

	return 0;
}

static const struct v4l2_subdev_video_ops cvs_csi_video_ops = {
	.s_stream = cvs_csi_set_stream,
};

static const struct v4l2_subdev_pad_ops cvs_csi_pad_ops = {
	.get_fmt = v4l2_subdev_get_fmt,
	.set_fmt = cvs_csi_set_fmt,
	.get_mbus_config = cvs_csi_get_mbus_config,
};

static const struct v4l2_subdev_ops cvs_csi_subdev_ops = {
	.video = &cvs_csi_video_ops,
	.pad = &cvs_csi_pad_ops,
};

static const struct v4l2_subdev_internal_ops cvs_csi_internal_ops = {
	.init_state = cvs_csi_init_state,
};

static const struct media_entity_operations cvs_csi_entity_ops = {
	.link_validate = v4l2_subdev_link_validate,
};

static int cvs_csi_notify_bound(struct v4l2_async_notifier *notifier,
				struct v4l2_subdev *subdev,
				struct v4l2_async_connection *asd)
{
	struct cvs_csi *csi = notifier_to_csi(notifier);
	int pad;

	pad = media_entity_get_fwnode_pad(&subdev->entity, asd->match.fwnode,
					  MEDIA_PAD_FL_SOURCE);
	if (pad < 0)
		return pad;

	csi->remote = &subdev->entity.pads[pad];

	return media_create_pad_link(&subdev->entity, pad, &csi->subdev.entity,
				     CVS_CSI_PAD_SINK,
				     MEDIA_LNK_FL_ENABLED |
				     MEDIA_LNK_FL_IMMUTABLE);
}

static void cvs_csi_notify_unbind(struct v4l2_async_notifier *notifier,
				  struct v4l2_subdev *subdev,
				  struct v4l2_async_connection *asd)
{
	struct cvs_csi *csi = notifier_to_csi(notifier);

	csi->remote = NULL;
}

static const struct v4l2_async_notifier_operations cvs_csi_notify_ops = {
	.bound = cvs_csi_notify_bound,
	.unbind = cvs_csi_notify_unbind,
};

/* Wait on the sensor behind our sink port, and pick up the CSI-2 lane count. */
static int cvs_csi_parse_fwnode(struct cvs_csi *csi)
{
	struct v4l2_fwnode_endpoint v4l2_ep = {
		.bus_type = V4L2_MBUS_CSI2_DPHY,
	};
	struct fwnode_handle *sink_ep, *source_ep;
	struct v4l2_async_connection *asd;
	struct device *dev = csi->dev;
	int ret;

	sink_ep = fwnode_graph_get_endpoint_by_id(dev_fwnode(dev), 0, 0, 0);
	if (!sink_ep) {
		dev_err(dev, "can't obtain sink endpoint\n");
		return -EINVAL;
	}

	v4l2_async_subdev_nf_init(&csi->notifier, &csi->subdev);
	csi->notifier.ops = &cvs_csi_notify_ops;

	ret = v4l2_fwnode_endpoint_parse(sink_ep, &v4l2_ep);
	if (ret) {
		dev_err(dev, "could not parse v4l2 sink endpoint\n");
		goto out_nf_cleanup;
	}

	csi->nr_of_lanes = v4l2_ep.bus.mipi_csi2.num_data_lanes;

	source_ep = fwnode_graph_get_endpoint_by_id(dev_fwnode(dev), 1, 0, 0);
	if (!source_ep) {
		ret = -ENOTCONN;
		dev_err(dev, "can't obtain source endpoint\n");
		goto out_nf_cleanup;
	}

	ret = v4l2_fwnode_endpoint_parse(source_ep, &v4l2_ep);
	fwnode_handle_put(source_ep);
	if (ret) {
		dev_err(dev, "could not parse v4l2 source endpoint\n");
		goto out_nf_cleanup;
	}

	if (csi->nr_of_lanes != v4l2_ep.bus.mipi_csi2.num_data_lanes) {
		ret = -EINVAL;
		dev_err(dev, "the number of lanes does not match (%u vs. %u)\n",
			csi->nr_of_lanes, v4l2_ep.bus.mipi_csi2.num_data_lanes);
		goto out_nf_cleanup;
	}

	asd = v4l2_async_nf_add_fwnode_remote(&csi->notifier, sink_ep,
					      struct v4l2_async_connection);
	if (IS_ERR(asd)) {
		ret = PTR_ERR(asd);
		goto out_nf_cleanup;
	}

	ret = v4l2_async_nf_register(&csi->notifier);
	if (ret)
		goto out_nf_cleanup;

	fwnode_handle_put(sink_ep);

	return 0;

out_nf_cleanup:
	v4l2_async_nf_cleanup(&csi->notifier);
	fwnode_handle_put(sink_ep);

	return ret;
}

static int cvs_csi_setup(struct cvs_csi *csi)
{
	int ret;

	ret = cvs_csi_parse_fwnode(csi);
	if (ret)
		return ret;

	csi->subdev.dev = csi->dev;
	csi->subdev.state_lock = &csi->lock;
	v4l2_subdev_init(&csi->subdev, &cvs_csi_subdev_ops);
	csi->subdev.internal_ops = &cvs_csi_internal_ops;
	v4l2_set_subdevdata(&csi->subdev, csi);
	csi->subdev.flags = V4L2_SUBDEV_FL_HAS_DEVNODE |
			    V4L2_SUBDEV_FL_HAS_EVENTS;
	csi->subdev.entity.function = MEDIA_ENT_F_VID_IF_BRIDGE;
	csi->subdev.entity.ops = &cvs_csi_entity_ops;
	snprintf(csi->subdev.name, sizeof(csi->subdev.name),
		 CVS_CSI_ENTITY_NAME);

	csi->pads[CVS_CSI_PAD_SINK].flags = MEDIA_PAD_FL_SINK;
	csi->pads[CVS_CSI_PAD_SOURCE].flags = MEDIA_PAD_FL_SOURCE;
	ret = media_entity_pads_init(&csi->subdev.entity, CVS_CSI_NUM_PADS,
				     csi->pads);
	if (ret)
		goto err_nf;

	ret = v4l2_subdev_init_finalize(&csi->subdev);
	if (ret)
		goto err_entity;

	ret = v4l2_async_register_subdev(&csi->subdev);
	if (ret)
		goto err_subdev;

	csi->registered = true;

	return 0;

err_subdev:
	v4l2_subdev_cleanup(&csi->subdev);
err_entity:
	media_entity_cleanup(&csi->subdev.entity);
err_nf:
	v4l2_async_nf_unregister(&csi->notifier);
	v4l2_async_nf_cleanup(&csi->notifier);

	return ret;
}

static void cvs_csi_bringup(struct work_struct *work)
{
	struct cvs_csi *csi =
		container_of(to_delayed_work(work), struct cvs_csi, bringup);
	struct fwnode_handle *ep;
	int ret;

	ep = fwnode_graph_get_endpoint_by_id(dev_fwnode(csi->dev), 0, 0, 0);
	if (!ep) {
		if (++csi->tries < CVS_CSI_POLL_TRIES) {
			schedule_delayed_work(&csi->bringup,
					      msecs_to_jiffies(CVS_CSI_POLL_MS));
			return;
		}

		dev_info(csi->dev,
			 "no camera fwnode graph after %u ms; not registering %s\n",
			 CVS_CSI_POLL_MS * CVS_CSI_POLL_TRIES,
			 CVS_CSI_ENTITY_NAME);
		return;
	}
	fwnode_handle_put(ep);

	ret = cvs_csi_setup(csi);
	if (ret)
		dev_err(csi->dev, "failed to register %s: %d\n",
			CVS_CSI_ENTITY_NAME, ret);
	else
		dev_info(csi->dev, "registered %s\n", CVS_CSI_ENTITY_NAME);
}

int cvs_csi_register(struct device *dev)
{
	struct cvs_csi *csi;

	if (cvs_csi)
		return 0;

	csi = devm_kzalloc(dev, sizeof(*csi), GFP_KERNEL);
	if (!csi)
		return -ENOMEM;

	csi->dev = dev;
	mutex_init(&csi->lock);
	mutex_init(&csi->stream_lock);
	INIT_DELAYED_WORK(&csi->bringup, cvs_csi_bringup);

	cvs_csi = csi;
	schedule_delayed_work(&csi->bringup, msecs_to_jiffies(CVS_CSI_POLL_MS));

	return 0;
}

void cvs_csi_unregister(struct device *dev)
{
	struct cvs_csi *csi = cvs_csi;

	if (!csi || csi->dev != dev)
		return;

	cancel_delayed_work_sync(&csi->bringup);

	if (csi->registered) {
		v4l2_async_nf_unregister(&csi->notifier);
		v4l2_async_nf_cleanup(&csi->notifier);
		v4l2_async_unregister_subdev(&csi->subdev);
		v4l2_subdev_cleanup(&csi->subdev);
		media_entity_cleanup(&csi->subdev.entity);
		csi->registered = false;
	}

	mutex_destroy(&csi->stream_lock);
	mutex_destroy(&csi->lock);

	cvs_csi = NULL;
}
