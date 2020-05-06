/*
 * Copyright (C) 2007-2008 Intel Corporation
 *
 *	Retrieve drive serial numbers for scsi disks
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St - Fifth Floor, Boston, MA 02110-1301 USA.
 */
#include <stdint.h>
#include <string.h>
#include <scsi/scsi.h>
#include <scsi/sg.h>
#include <sys/ioctl.h>

//https://github.com/intel/IntelRackScaleArchitecture/blob/master/RSA-SW/PSME/agent/storage/src/sysfs/sysfs_api.cpp
void read_ata_string(char *value, uint16_t *hdio_data, size_t offset, size_t length) {
	if (0 == hdio_data[offset]) {
		return;
	}

	for (size_t pos = 0; pos < length; ++pos) {
		uint16_t data_word = hdio_data[offset + pos];
		value[pos * 2] = (char)((data_word >> 8) & 0xff);
		value[pos * 2 + 1] = (char)(data_word & 0xff);
	}
	//trim(value);
}

int read_serial_number(char *serial_number, size_t buf_len, uint16_t *hdio_data) {
	static const uint32_t SERIAL_OFFSET = 12;
	static const uint32_t SERIAL_LENGTH = 10;

	if(buf_len < SERIAL_LENGTH)
		return -1;

	read_ata_string(serial_number, hdio_data, SERIAL_OFFSET, SERIAL_LENGTH);
	return 0;
}


int scsi_get_serial_new(int fd, void *buf, size_t buf_len)
{
	static const size_t ATA_DATA_SIZE = 512+4;
	static const size_t COMMAND_BUFFER_SIZE = 16;
	static const size_t SENSE_BUFFER_SIZE = 32;
	static const uint32_t SG_IO_TIMEOUT = 2000;
	static const uint8_t ATA_OP_IDENTIFY = 0xec;
	static const uint8_t SG_ATA_16 = 0x85;
	static const uint8_t SG_ATA_PROTO_PIO_IN = 0x08;
	static const uint8_t SG_CDB2_TLEN_NSECT = 0x02;
	static const uint8_t SG_CDB2_TLEN_SECTORS = 0x04;
	static const uint8_t SG_CDB2_TDIR_FROM_DEV = 0x08;
	static const uint8_t ATA_USING_LBA = 0x40;

	uint16_t hdio_data[ATA_DATA_SIZE/2];

	uint8_t command_buffer[COMMAND_BUFFER_SIZE];
	uint8_t sense_buffer[SENSE_BUFFER_SIZE];
	uint8_t* data_buffer = (uint8_t*)(hdio_data + 2);
	sg_io_hdr_t io_hdr;
	int rv;

	memset(&io_hdr, 0, sizeof(io_hdr));
	memset(command_buffer, 0, COMMAND_BUFFER_SIZE);
	memset(sense_buffer, 0, SENSE_BUFFER_SIZE);
	memset(hdio_data, 0, ATA_DATA_SIZE);

	command_buffer[0] = SG_ATA_16;
	command_buffer[1] = SG_ATA_PROTO_PIO_IN;
	command_buffer[2] =
		SG_CDB2_TLEN_NSECT | SG_CDB2_TLEN_SECTORS | SG_CDB2_TDIR_FROM_DEV;
	command_buffer[6] = 1;     // number of sectors
	command_buffer[13] = ATA_USING_LBA;
	command_buffer[14] = ATA_OP_IDENTIFY;

	io_hdr.interface_id = 'S';
	io_hdr.cmd_len = COMMAND_BUFFER_SIZE;
	io_hdr.mx_sb_len = SENSE_BUFFER_SIZE;
	io_hdr.dxfer_direction = SG_DXFER_FROM_DEV;
	io_hdr.dxfer_len = ATA_DATA_SIZE - 2;
	io_hdr.dxferp = data_buffer;
	io_hdr.cmdp = command_buffer;
	io_hdr.sbp = sense_buffer;
	io_hdr.timeout = SG_IO_TIMEOUT;

	rv = ioctl(fd, SG_IO, &io_hdr);
	if(rv)
		return rv;

	return read_serial_number(buf, buf_len, hdio_data);
}

int scsi_get_serial(int fd, void *buf, size_t buf_len)
{
	unsigned char rsp_buf[255];
	unsigned char inq_cmd[] = {INQUIRY, 1, 0x80, 0, sizeof(rsp_buf), 0};
	unsigned char sense[32];
	struct sg_io_hdr io_hdr;
	int rv;
	unsigned int rsp_len;
	memset(&io_hdr, 0, sizeof(io_hdr));
	io_hdr.interface_id = 'S';
	io_hdr.cmdp = inq_cmd;
	io_hdr.cmd_len = sizeof(inq_cmd);
	io_hdr.dxferp = rsp_buf;
	io_hdr.dxfer_len = sizeof(rsp_buf);
	io_hdr.dxfer_direction = SG_DXFER_FROM_DEV;
	io_hdr.sbp = sense;
	io_hdr.mx_sb_len = sizeof(sense);
	io_hdr.timeout = 5000;
	rv = ioctl(fd, SG_IO, &io_hdr);
	if (rv)
		return rv;
	if ((io_hdr.info & SG_INFO_OK_MASK) != SG_INFO_OK)
		return -1;
	rsp_len = rsp_buf[3];
	if (!rsp_len || buf_len < rsp_len)
		return -1;
	memcpy(buf, &rsp_buf[4], rsp_len);
	return 0;
}
