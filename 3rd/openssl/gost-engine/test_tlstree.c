/*
 * Copyright (c) 2019-2020 Dmitry Belyavskiy <beldmit@gmail.com>
 *
 * Contents licensed under the terms of the OpenSSL license
 * See https://www.openssl.org/source/license.html for details
 */
#ifdef _MSC_VER
# pragma warning(push, 3)
# include <openssl/applink.c>
# pragma warning(pop)
#endif
# include <stdio.h>
# include <string.h>
# include <openssl/err.h>
# include <openssl/evp.h>

static void hexdump(FILE *f, const char *title, const unsigned char *s, int l)
{
    int n = 0;

    fprintf(f, "%s", title);
    for (; n < l; ++n) {
        if ((n % 16) == 0)
            fprintf(f, "\n%04x", n);
        fprintf(f, " %02x", s[n]);
    }
    fprintf(f, "\n");
}

int main(void)
{
#ifdef EVP_MD_CTRL_TLSTREE
	const unsigned char mac_secret[] = {
0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	};

	const unsigned char enc_key[] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	};

	const unsigned char full_iv[] = {
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	};


	unsigned char seq0[] = {
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	};

	const unsigned char rec0_header[] = {
0x17, 0x03, 0x03, 0x00, 0x0F
	};

	const unsigned char data0[15] = {
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	};

	const unsigned char mac0_etl[16] = {
0x75, 0x53, 0x09, 0xCB, 0xC7, 0x3B, 0xB9, 0x49, 0xC5, 0x0E, 0xBB, 0x86, 0x16, 0x0A, 0x0F, 0xEE
	};

	const unsigned char enc0_etl[31] = {
0xf3, 0x17, 0xa7, 0x1d, 0x3a, 0xce, 0x43, 0x3b, 0x01, 0xd4, 0xe7, 0xd4, 0xef, 0x61, 0xae, 0x00,
0xd5, 0x3b, 0x41, 0x52, 0x7a, 0x26, 0x1e, 0xdf, 0xc2, 0xba, 0x78, 0x57, 0xc1, 0x93, 0x2d
	};

	unsigned char data0_processed[31];
	unsigned char mac0[16];

	unsigned char seq63[] = {
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F,
	};

	const unsigned char rec63_header[] = {
0x17, 0x03, 0x03, 0x10, 0x00
	};

	unsigned char data63[4096];

	const unsigned char mac63_etl[16] = {
0x0A, 0x3B, 0xFD, 0x43, 0x0F, 0xCD, 0xD8, 0xD8, 0x5C, 0x96, 0x46, 0x86, 0x81, 0x78, 0x4F, 0x7D
	};

	const unsigned char enc63_etl_head[32] = {
0x6A, 0x18, 0x38, 0xB0, 0xA0, 0xD5, 0xA0, 0x4D, 0x1F, 0x29, 0x64, 0x89, 0x6D, 0x08, 0x5F, 0xB7, 
0xDA, 0x84, 0xD7, 0x76, 0xC3, 0x9F, 0x5C, 0xDC, 0x37, 0x20, 0xB7, 0xB5, 0x59, 0xEF, 0x13, 0x9D
	};
	const unsigned char enc63_etl_tail[48] = {
0x0A, 0x81, 0x29, 0x9B, 0x35, 0x98, 0x19, 0x5D, 0xD4, 0x51, 0x68, 0xA6, 0x38, 0x50, 0xA7, 0x6E, 
0x1A, 0x4F, 0x1E, 0x6D, 0xD5, 0xEF, 0x72, 0x59, 0x3F, 0xAE, 0x76, 0x55, 0x71, 0xEC, 0x37, 0xE7, 
0x17, 0xF5, 0xB8, 0x62, 0x85, 0xBB, 0x5B, 0xFD, 0x83, 0xB6, 0x6A, 0xB7, 0x63, 0x86, 0x52, 0x08
	};

	unsigned char data63_processed[4096+16];
	unsigned char mac63[16];

	EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
	EVP_CIPHER_CTX *enc = NULL;
	const EVP_MD *md;
	const EVP_CIPHER *ciph;
	EVP_PKEY *mac_key;
	size_t mac_len;
	int i;

	OPENSSL_init_crypto(OPENSSL_INIT_LOAD_CONFIG, NULL);

	memset(data63, 0, 4096);

	md = EVP_get_digestbynid(NID_grasshopper_mac);

	EVP_DigestInit_ex(mdctx, md, NULL);
  mac_key = EVP_PKEY_new_mac_key(NID_grasshopper_mac, NULL, mac_secret, 32);
  EVP_DigestSignInit(mdctx, NULL, md, NULL, mac_key);
  EVP_PKEY_free(mac_key);

	EVP_MD_CTX_ctrl(mdctx, EVP_MD_CTRL_TLSTREE, 0, seq0);
	EVP_DigestSignUpdate(mdctx, seq0, 8);
	EVP_DigestSignUpdate(mdctx, rec0_header, 5);
	EVP_DigestSignUpdate(mdctx, data0, 15);
	EVP_DigestSignFinal(mdctx, mac0, &mac_len);

	EVP_MD_CTX_free(mdctx);
	hexdump(stderr, "MAC0 result", mac0, mac_len);
	if (memcmp(mac0, mac0_etl, 16) != 0) {
		fprintf(stderr, "MAC0 mismatch");
		exit(1);
	}

	ciph = EVP_get_cipherbynid(NID_id_tc26_cipher_gostr3412_2015_kuznyechik_ctracpkm);
	enc = EVP_CIPHER_CTX_new();
	if (EVP_EncryptInit_ex(enc, ciph, NULL, enc_key, full_iv) <= 0) {
		fprintf(stderr, "Internal error");
		exit(1);
	}

	for (i = 7; i >= 0; i--) {
		++seq0[i];
		if (seq0[i] != 0)
			break;
	}
	EVP_CIPHER_CTX_ctrl(enc, EVP_CTRL_TLSTREE, 0, seq0);
	EVP_Cipher(enc, data0_processed, data0, sizeof(data0));
	EVP_Cipher(enc, data0_processed+sizeof(data0), mac0, 16);

	hexdump(stderr, "ENC0 result", data0_processed, 31);
	if (memcmp(enc0_etl, data0_processed, sizeof(data0_processed)) != 0) {
		fprintf(stderr, "ENC0 mismatch");
		exit(1);
	}

	mdctx = EVP_MD_CTX_new();
	EVP_DigestInit_ex(mdctx, md, NULL);
  mac_key = EVP_PKEY_new_mac_key(NID_grasshopper_mac, NULL, mac_secret, 32);
  EVP_DigestSignInit(mdctx, NULL, md, NULL, mac_key);
  EVP_PKEY_free(mac_key);

	EVP_MD_CTX_ctrl(mdctx, EVP_MD_CTRL_TLSTREE, 0, seq63);
	EVP_DigestSignUpdate(mdctx, seq63, 8);
	EVP_DigestSignUpdate(mdctx, rec63_header, 5);
	EVP_DigestSignUpdate(mdctx, data63, 4096);
	EVP_DigestSignFinal(mdctx, mac63, &mac_len);

	EVP_MD_CTX_free(mdctx);
	hexdump(stderr, "MAC63 result", mac63, mac_len);
	if (memcmp(mac63, mac63_etl, 16) != 0) {
		fprintf(stderr, "MAC63 mismatch");
		exit(1);
	}

	for (i = 7; i >= 0; i--) {
		++seq63[i];
		if (seq63[i] != 0)
			break;
	}
	EVP_CIPHER_CTX_ctrl(enc, EVP_CTRL_TLSTREE, 0, seq63);
	EVP_Cipher(enc, data63_processed, data63, sizeof(data63));
	EVP_Cipher(enc, data63_processed+sizeof(data63), mac63, 16);

	hexdump(stderr, "ENC63 result: head", data63_processed, 32);
	if (memcmp(enc63_etl_head, data63_processed, sizeof(enc63_etl_head)) != 0) {
		fprintf(stderr, "ENC63 mismatch: head");
		exit(1);
	}
	hexdump(stderr, "ENC63 result: tail", data63_processed+4096+16-48, 48);
	if (memcmp(enc63_etl_tail, data63_processed+4096+16-48, sizeof(enc63_etl_tail)) != 0) {
		fprintf(stderr, "ENC63 mismatch: tail");
		exit(1);
	}

#endif
	return 0;
}
