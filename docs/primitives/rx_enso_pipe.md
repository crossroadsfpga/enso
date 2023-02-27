# RX Ensō Pipe

RX Ensō Pipes are used to *receive* data from the NIC. RX Ensō Pipes support different ways of receiving data, depending on the level of abstraction supported by the NIC and expected by the application: raw packets, application-level messages, or a byte stream.

Stuff to discuss:

- Bind
- Different ways of receiving data
    - Recv vs Peek
    - ConfirmBytes
    - Byte stream
    - Raw packets
    - Generic messages
        - Raw packets is just a special case of generic messages
        - How to specify the message format
- Free/Clear
