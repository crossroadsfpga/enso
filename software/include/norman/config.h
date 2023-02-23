/*
 * Copyright (c) 2022, Carnegie Mellon University
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted (subject to the limitations in the disclaimer
 * below) provided that the following conditions are met:
 *
 *      * Redistributions of source code must retain the above copyright notice,
 *      this list of conditions and the following disclaimer.
 *
 *      * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *      * Neither the name of the copyright holder nor the names of its
 *      contributors may be used to endorse or promote products derived from
 *      this software without specific prior written permission.
 *
 * NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
 * THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Functions to configure the data plane.
 *
 * Authors:
 *   Hugo Sadok <sadok@cmu.edu>
 */

#ifndef SOFTWARE_INCLUDE_NORMAN_CONFIG_H_
#define SOFTWARE_INCLUDE_NORMAN_CONFIG_H_

#include <norman/internals.h>

namespace norman {

/**
 * Inserts flow entry in the data plane flow table that will direct all packets
 * matching the flow entry to the `enso_pipe_id`.
 *
 * @param notification_buf_pair Notification buffer to send configuration
 *                              through.
 * @param dst_port Destination port number of the flow entry.
 * @param src_port Source port number of the flow entry.
 * @param dst_ip Destination IP address of the flow entry.
 * @param src_ip Source IP address of the flow entry.
 * @param protocol Protocol of the flow entry.
 * @param enso_pipe_id Enso Pipe ID that will be associated with the flow entry.
 *
 *
 * @return Return 0 if configuration was successful.
 */
int insert_flow_entry(struct NotificationBufPair* notification_buf_pair,
                      uint16_t dst_port, uint16_t src_port, uint32_t dst_ip,
                      uint32_t src_ip, uint32_t protocol,
                      uint32_t enso_pipe_id);

/**
 * Sends configuration to the dataplane.
 *
 * @param notification_buf_pair Notification buffer to send configuration
 *                              through.
 * @param config_notification Configuration notification.
 *
 * @return Return 0 if configuration was successful.
 */
int send_config(struct NotificationBufPair* notification_buf_pair,
                struct TxNotification* config_notification);

/**
 * Enables hardware timestamping.
 *
 * All outgoing packets will receive a timestamp and all incoming packets will
 * have an RTT (in number of cycles). Use `get_pkt_rtt` to retrieve the value.
 *
 * @param notification_buf_pair Notification buffer to send configuration
 *                              through.
 * @return 0 if configuration was successful.
 */
int enable_timestamp(struct NotificationBufPair* notification_buf_pair);

/**
 * Disables hardware timestamping.
 * @param notification_buf_pair Notification buffer to send configuration
 *                              through.
 * @return 0 if configuration was successful.
 */
int disable_timestamp(struct NotificationBufPair* notification_buf_pair);

/**
 * Disables hardware rate limit.
 *
 * @param notification_buf_pair Notification buffer to send configuration
 *                              through.
 * @return 0 if configuration was successful.
 */
int disable_rate_limit(struct NotificationBufPair* notification_buf_pair);

/**
 * Enables hardware rate limit.
 *
 * Once rate limiting is enabled, packets from all queues are sent at a rate of
 * (num/den * MAX_HARDWARE_FLIT_RATE) flits per second (a flit is 64 bytes).
 * Note that this is slightly different from how we typically define throughput
 * and you may need to take the packet sizes into account to set this properly.
 *
 * For example, suppose that you are sending 64-byte packets. Each packet
 * occupies exactly one flit. For this packet size, line rate at 100 Gbps is
 * 148.8Mpps. So if MAX_HARDWARE_FLIT_RATE is 200MHz, line rate actually
 * corresponds to a 744/1000 rate. Therefore, if you want to send at 50Gbps (50%
 * of line rate), you can use a 372/1000 (or 93/250) rate.
 *
 * The other thing to notice is that, while it might be tempting to use a large
 * denominator in order to increase the rate precision. This has the side effect
 * of increasing burstiness. The way the rate limit is implemented, we send a
 * burst of `num` consecutive flits every `den` cycles. Which means that if
 * `num` is too large, it might overflow the receiver buffer. For instance, in
 * the example above, 93/250 would be a better rate than 372/1000. And 3/8 would
 * be even better with a slight loss in precision.
 *
 * You can find the maximum packet rate for any packet size by using the
 * expression: line_rate/((pkt_size + 20)*8). So for 100Gbps and 128-byte
 * packets we have: 100e9/((128+20)*8) packets per second. Given that each
 * packet is two flits, for MAX_HARDWARE_FLIT_RATE=200e6, the maximum rate is
 * 100e9/((128+20)*8)*2/200e6, which is approximately 125/148.
 *
 * @param notification_buf_pair Notification buffer to send configuration
 *                              through.
 * @param num Rate numerator.
 * @param den Rate denominator.
 * @return 0 if configuration was successful.
 */
int enable_rate_limit(struct NotificationBufPair* notification_buf_pair,
                      uint16_t num, uint16_t den);

}  // namespace norman

#endif  // SOFTWARE_INCLUDE_NORMAN_CONFIG_H_
