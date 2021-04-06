#define JD_REG_RW_STREAMING_SAMPLES 0x03
#define JD_REG_RW_STREAMING_INTERVAL 0x04

#define JD_REG_RO_READING 0x01

#define SENSOR_SIZE 1

	BYTE streaming_samples
	BYTE streaming_interval
	BYTE t_streaming
	BYTE sensor_state[SENSOR_SIZE]

	mov a, rx_cmd_h

	if (a == JD_HIGH_REG_RW_SET) {
		mov a, rx_cmd_l

		if (a == JD_REG_RW_STREAMING_SAMPLES) {
			.mova streaming_samples, rx_data_0
			goto rx_process_end
		}

		if (a == JD_REG_RW_STREAMING_INTERVAL) {
			mov a, rx_data_1
			ifneq a, 0
				goto streaming_int_ovf
			mov a, rx_data_0
			sl a
			ifset CF
				goto streaming_int_ovf
			mov a, rx_data_0
			goto streaming_int_set

		streaming_int_ovf:
			mov a, 127
		streaming_int_set:
			mov streaming_interval, a
			add a, t16_1ms
			mov t_streaming, a
			// goto rx_process_end
		}

		goto rx_process_end
	}

	ifset flags.f_has_tx
	  goto pkt_overflow

	if (a == JD_HIGH_REG_RW_GET) {
		mov a, rx_cmd_l

		if (a == JD_REG_RW_STREAMING_SAMPLES) {
			.mova tx_payload[0], streaming_samples
			.mova tx_size, 1
			goto prep_answer
		}

		if (a == JD_REG_RW_STREAMING_INTERVAL) {
			.mova tx_payload[0], streaming_interval
			clear tx_payload[1]
			clear tx_payload[2]
			clear tx_payload[3]
			.mova tx_size, 4
			goto prep_answer
		}

		goto rx_process_end
	}


	if (a == JD_HIGH_REG_RO_GET) {
		mov a, rx_cmd_l

		if (a == JD_REG_RO_READING) {
			call send_reading
			// goto rx_process_end
		}
		
		// goto rx_process_end
	}

	goto rx_process_end

prep_answer:
	set1 flags.f_has_tx
	.mova tx_service_command_h, rx_cmd_h
	.mova rx_service_num, tx_service_number
	.mova tx_service_command_l, rx_cmd_l
	goto rx_process_end

send_reading:
	_cnt => 0
.repeat SENSOR_SIZE
	.mova tx_payload[_cnt], sensor_state[_cnt]
	_cnt => _cnt + 1
.endm
	.mova tx_size, SENSOR_SIZE
	set1 flags.f_has_tx
	.mova tx_service_command_h, JD_HIGH_REG_RO_GET
	.mova rx_service_num, 1
	.mova tx_service_command_l, JD_REG_RO_READING
	ret

.sensor_stream MACRO
	mov a, streaming_samples
	ifset ZF
	  goto skip_stream
	.t16_chk t16_1ms, t_streaming, <goto do_stream>
	goto skip_stream
do_stream:
	dec streaming_samples
	call send_reading
	goto loop
skip_stream:
ENDM