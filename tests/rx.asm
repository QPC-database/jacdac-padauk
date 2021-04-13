#define rx_buflimit isr0

.rx_init MACRO
	PAPH.JD_D = 1
	call reset_tm2
	TM2B = 64 // irq every 64 instructions, 8us
	$ TM2C SYSCLK
	$ INTEN = TM2
ENDM

reset_tm2:
	mov a, 0
	mov TM2CT, a
	mov INTRQ, a
	$ TM2S 8BIT, /1, /1
	set1 flags.f_set_tx
	ret

	// TODO we have about 14 instructions free here

	.romadr	0x10            // interrupt vector
interrupt:
	INTRQ.TM2 = 0
	ifset flags.f_in_rx
	  goto timeout
	ifset PA.JD_D
	  reti

	pushaf

	.pulse_log

	// seed the PRNG with reception time of each packet
	.rng_add_entropy

	set1 flags.f_in_rx
	$ TM2S 8BIT, /1, /17 // ~136us
	.mova TM2CT, 0
	engint

	// wait for end of lo pulse
@@:
	ifclear PA.JD_D
	  goto @b

	.mova memidx$0, pkt_addr
	.mova rx_buflimit, buffer_size+1

	clear frm_sz // make sure packet is invalid, if we do not recv anything
	mov a, 0
	goto rx_wait_start

    .include devid.asm

rx_start:
	mov TM2CT, a
	$ TM2S 8BIT, /1, /2	 // 2T
	clear rx_data
	nop
	mov a, 0x01
rx_next_bit:
	ifset PA.JD_D
		or rx_data, a
	nop
	sl a
	nop
	ceqsn a, 0x80
		goto rx_next_bit
rx_lastbit:
	nop
	ifset PA.JD_D
		or rx_data, a
	mov a, rx_data
	idxm memidx, a   	// 2T
	dzsn rx_buflimit    // rx_buflimit--
		inc memidx$0    // when rx_buflimit reaches 0, we stop incrementing memidx
	ifset ZF          	// if rx_buflimit==0
		inc rx_buflimit //     rx_buflimit++ -> keep rx_buflimit at 0
	mov a, 0
	mov TM2CT, a
// wait for serial transmission to start
rx_wait_start:
.repeat 20
	ifclear PA.JD_D
	  goto rx_start
.endm
	goto rx_wait_start

got_client_announce:
	set0 blink.blink_disconnected
	mov a, t16_262ms
	sr a
	and a, 0x3
	set0 blink.0
	set0 blink.1
	or blink, a
	ret

timeout:
	PA.JD_LED = 1

	// this is nested IRQ; we want to return to original code, not outer interrupt
	// TODO: try fake popaf
	mov a, SP
	sub a, 2
	mov SP, a

leave_irq:
	.blink_rx

	mov a, frm_flags
	and a, (1 << JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS)
	if (ZF) {
    	.check_id not_interested // uses isr0, isr1
	} else {
		.forc x, <0123>
		mov a, pkt_device_id[x]
		ifneq a, (SERVICE_CLASS >> (x * 8)) & 0xff
			goto not_interested
		.endm
	}

	// we have to check size before checking CRC
	mov a, frm_sz
	sub a, buffer_size-frame_header_size+1
	ifclear CF
	  goto pkt_error // it was a packet for us, but it was too large

	// save crc_l/h for future comparison
	.mova rx_data, crc_l
	.mova isr2, crc_h
	mov a, 0xff
	mov crc_l, a
	mov crc_h, a
	.mova memidx$0, pkt_addr+2
	mov a, frm_sz
	add a, 10
	call crc16 // uses isr0,1

	mov a, crc_l
	ifneq a, rx_data
	  goto pkt_error
	mov a, crc_h
	ifneq a, isr2
	  goto pkt_error

	.mova isr0, frm_flags
	ifclear isr0.JD_FRAME_FLAG_COMMAND
	  goto not_interested // this is a report
	ifset isr0.JD_FRAME_FLAG_VNEXT
	  goto pkt_error
	
	mov a, 1
	ifset isr0.JD_FRAME_FLAG_IDENTIFIER_IS_SERVICE_CLASS
		mov pkt_service_number, a

	if (isr0.JD_FRAME_FLAG_ACK_REQUESTED) {
		set1 tx_pending.txp_ack
		.mova ack_crc_l, crc_l
		.mova ack_crc_h, crc_h
	}

	// sync the timer before packet processing - it may need the current value
	call t16_sync

.include rxctrl.asm

not_interested:
_do_leave:
	// sync the timer, in case we interrupted the main loop just before it checks for f_set_tx
	call t16_sync
	set0 flags.f_in_rx
	call reset_tm2
	popaf
	PA.JD_LED = 0
	reti

pkt_overflow:
pkt_invalid:
pkt_error:
	.pulse_log
	.pulse_log
	goto _do_leave
