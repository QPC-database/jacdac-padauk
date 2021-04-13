#define JD_FRAME_FLAG_COMMAND 0
#define JD_FRAME_FLAG_ACK_REQUESTED 1
#define JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS 2
#define JD_FRAME_FLAG_VNEXT 7

#define JD_AD0_IS_CLIENT_MSK 0x08

#define JD_HIGH_CMD 0x00
#define JD_HIGH_REG_RW_SET 0x20
#define JD_HIGH_REG_RW_GET 0x10
#define JD_HIGH_REG_RO_GET 0x11

#define JD_CONTROL_CMD_IDENTIFY 0x81
#define JD_CONTROL_CMD_RESET 0x82
#define JD_CONTROL_CMD_SET_STATUS_LIGHT 0x84

#define JD_CONTROL_REG_RW_RESET_IN 0x80

#define JD_REG_RW_STREAMING_SAMPLES 0x03
#define JD_REG_RW_STREAMING_INTERVAL 0x04
#define JD_REG_RO_READING 0x01

frame_header_size equ 12
crc_size equ 2
payload_size equ 8
buffer_size equ (frame_header_size + 4 + payload_size)

f_in_rx equ 0
f_set_tx equ 1
// f_identify equ 2
f_reset_in equ 3
f_ev1 equ 4
f_ev2 equ 5
f_announce_t16_bit equ 6
f_announce_rst_cnt_max equ 7

blink_identify equ 3
blink_identify_was0 equ 4
blink_disconnected equ 5
blink_status_on equ 6

txp_announce equ 0
txp_ack equ 1
txp_streaming_samples equ 2
txp_streaming_interval equ 3
txp_reading equ 4
txp_event equ 5

pkt_addr equ 0x10

.include utils.asm
.include t16.asm
.include rng.asm
.include blink.asm

	.ramadr 0x00
	WORD    memidx
	BYTE    flags
	BYTE    tx_pending
	BYTE	isr0, isr1, isr2
	BYTE    rng_x

	BYTE    blink
	BYTE    ack_crc_l, ack_crc_h

	BYTE	t16_16ms
	WORD    t16_low
	WORD    t16_high

	.ramadr pkt_addr
	BYTE	crc_l, crc_h
	BYTE	frm_sz
	BYTE    frm_flags

	BYTE    pkt_device_id[8]

	// actual tx packet
	BYTE	pkt_size
	BYTE	pkt_service_number
	BYTE	pkt_service_command_l
	BYTE	pkt_service_command_h
	BYTE	pkt_payload[payload_size]
	BYTE	rx_data // this is overwritten during rx if packet too long (but that's fine)

	BYTE    t_tx

	// so far:
	// application is not using stack when IRQ enabled
	// rx ISR can do up to 3
	WORD	main_st[3]

	BYTE    t_reset

#define JD_BUTTON_EV_DOWN 0x01
#define JD_BUTTON_EV_UP 0x02
#define JD_BUTTON_EV_HOLD 0x81


	// more data defined in rxserv.asm

	goto	main

	.include rx.asm
	.include crc16.asm
	.include tx.asm
