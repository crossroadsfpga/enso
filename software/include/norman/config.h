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
 */

#ifndef SOFTWARE_INCLUDE_NORMAN_CONFIG_H_
#define SOFTWARE_INCLUDE_NORMAN_CONFIG_H_

#include <norman/internals.h>

namespace norman {

/**
 * insert_flow_entry() - Insert flow entry in the data plane flow table.
 * @notification_buf_pair: Notification buffer to send configuration through.
 * @dst_port: Destination port number of the flow entry.
 * @src_port: Source port number of the flow entry.
 * @dst_ip: Destination IP address of the flow entry.
 * @src_ip: Source IP address of the flow entry.
 * @protocol: Protocol of the flow entry.
 * @enso_pipe_id: Enso Pipe ID that will be associated with the flow entry.
 *
 * Inserts a rule in the data plane flow table that will direct all packets
 * matching the flow entry to the `enso_pipe_id`.
 *
 * Return: Return 0 if configuration was successful.
 */
int insert_flow_entry(struct NotificationBufPair* notification_buf_pair,
                      uint16_t dst_port, uint16_t src_port, uint32_t dst_ip,
                      uint32_t src_ip, uint32_t protocol,
                      uint32_t enso_pipe_id);

/**
 * send_config() - Send configuration to the dataplane.
 * @notification_buf_pair: Notification buffer to send configuration through.
 * @config_notification: Configuration notification.
 *
 * Return: Return 0 if configuration was successful.
 */
int send_config(struct NotificationBufPair* notification_buf_pair,
                struct TxNotification* config_notification);

}  // namespace norman

#endif  // SOFTWARE_INCLUDE_NORMAN_CONFIG_H_
