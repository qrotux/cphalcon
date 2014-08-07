
/*
 +------------------------------------------------------------------------+
 | Phalcon Framework                                                      |
 +------------------------------------------------------------------------+
 | Copyright (c) 2011-2014 Phalcon Team (http://www.phalconphp.com)       |
 +------------------------------------------------------------------------+
 | This source file is subject to the New BSD License that is bundled     |
 | with this package in the file docs/LICENSE.txt.                        |
 |                                                                        |
 | If you did not receive a copy of the license and are unable to         |
 | obtain it through the world-wide-web, please send an email             |
 | to license@phalconphp.com so we can send you a copy immediately.       |
 +------------------------------------------------------------------------+
 | Authors: Andres Gutierrez <andres@phalconphp.com>                      |
 |          Eduar Carvajal <eduar@phalconphp.com>                         |
 +------------------------------------------------------------------------+
 */

namespace Phalcon;

use Phalcon\Crypt\Exception;

/**
 * Phalcon\Crypt
 *
 * Provides encryption facilities to phalcon applications
 *
 *<code>
 *	$crypt = new \Phalcon\Crypt();
 *
 *	$key = 'le password';
 *	$text = 'This is a secret text';
 *
 *	$encrypted = $crypt->encrypt($text, $key);
 *
 *	echo $crypt->decrypt($encrypted, $key);
 *</code>
 */
class Crypt implements \Phalcon\CryptInterface
{

	protected _key;

	protected _padding = 0;

	protected _mode = "cbc";

	protected _cipher = "rijndael-256";

	const PADDING_DEFAULT = 0;
	const PADDING_ANSI_X_923 = 1;
	const PADDING_PKCS7 = 2;
	const PADDING_ISO_10126 = 3;
	const PADDING_ISO_IEC_7816_4 = 4;
	const PADDING_ZERO = 5;
	const PADDING_SPACE = 6;

	/**
	* @brief Phalcon\CryptInterface Phalcon\Crypt::setPadding(int $scheme)
	*
	* @param int scheme Padding scheme
	* @return Phalcon\CryptInterface
	*/
	public function setPadding(int! scheme)
	{
		let this->_padding = scheme;
	}

	/**
	 * Sets the cipher algorithm
	 *
	 * @param string cipher
	 * @return Phalcon\Crypt
	 */
	public function setCipher(string! cipher) -> <Crypt>
	{
		let this->_cipher = cipher;
		return this;
	}

	/**
	 * Returns the current cipher
	 *
	 * @return string
	 */
	public function getCipher() -> string
	{
		return this->_cipher;
	}

	/**
	 * Sets the encrypt/decrypt mode
	 *
	 * @param string cipher
	 * @return Phalcon\Crypt
	 */
	public function setMode(string! mode) -> <Crypt>
	{
		let this->_mode = mode;
		return this;
	}

	/**
	 * Returns the current encryption mode
	 *
	 * @return string
	 */
	public function getMode() -> string
	{
		return this->_mode;
	}

	/**
	 * Sets the encryption key
	 *
	 * @param string key
	 * @return Phalcon\Crypt
	 */
	public function setKey(string! key) -> <\Phalcon\Crypt>
	{
		let this->_key = key;
		return this;
	}

	/**
	 * Returns the encryption key
	 *
	 * @return string
	 */
	public function getKey() -> string
	{
		return this->_key;
	}

	/**
	 * Adds padding @a padding_type to @a text
	 *
	 * @param return_value Result, possibly padded
	 * @param text Message to be padded
	 * @param mode Encryption mode; padding is applied only in CBC or ECB mode
	 * @param block_size Cipher block size
	 * @param padding_type Padding scheme
	 * @see http://www.di-mgt.com.au/cryptopad.html
	 */
	private function _cryptPadText(string! text, string! mode, int! blockSize, int! paddingType)
	{
		int i;
		var paddingSize = 0, padding = null;

		if mode == "cbc" || mode == "ecb" {

			let paddingSize = blockSize - (strlen(text) % blockSize);
			if paddingSize >= 256 {
				throw new Exception("Block size is bigger than 256");
			}

			switch paddingType {

				case self::PADDING_ANSI_X_923:
					//memset(padding, 0, padding_size - 1);
					//padding[padding_size-1] = (unsigned char)padding_size;
					let padding = str_repeat(chr(0), paddingSize - 1) . chr(paddingSize);
					break;

				case self::PADDING_PKCS7:
					//memset(padding, padding_size, padding_size);
					let padding = str_repeat(paddingSize, paddingSize);
					break;

				case self::PADDING_ISO_10126:
					let padding = "";
					for i in range(0, paddingSize - 1) {
						let padding .= chr(rand());
					}
					let padding .= chr(paddingSize);
					break;

				case self::PADDING_ISO_IEC_7816_4:
					//padding[0] = 0x80;
					//memset(padding + 1, 0, padding_size - 1);
					let padding = chr(0x80) . str_repeat(chr(0), paddingSize - 1);
					break;

				case self::PADDING_ZERO:
					//memset(padding, 0, padding_size);
					let padding = str_repeat(chr(0), paddingSize);
					break;

				case self::PADDING_SPACE:
					//memset(padding, 0x20, padding_size);
					let padding = str_repeat(" ", paddingSize);
					break;

				default:
					//padding_size = 0;
					let paddingSize = 0;
					break;

			}

		}

		if !paddingSize {
			return text;
		}

		if paddingSize > blockSize {
			throw new Exception("Invalid padding size");
		}

		return text . substr(padding, 0, paddingSize);
	}

	/**
	 * Removes padding @a padding_type from @a text
	 * If the function detects that the text was not padded, it will return it unmodified
	 *
	 * @param return_value Result, possibly unpadded
	 * @param text Message to be unpadded
	 * @param mode Encryption mode; unpadding is applied only in CBC or ECB mode
	 * @param block_size Cipher block size
	 * @param padding_type Padding scheme
	 */
	private function _cryptUnpadText(string! text, string! mode, int! blockSize, int! paddingType)
	{
		var paddingSize, padding, last;
		long length;

		let length = strlen(text);
		if length > 0 && (length % blockSize == 0) && (mode == "cbc" || mode == "ecb") {

			switch paddingType {

				case self::PADDING_ANSI_X_923:
					/*if ((unsigned char)(str_text[text_len - 1]) <= block_size) {
						padding_size = str_text[text_len - 1];

						memset(padding, 0, padding_size - 1);
						padding[padding_size-1] = (unsigned char)padding_size;

						if (memcmp(padding, str_text + text_len - padding_size, padding_size)) {
							padding_size = 0;
						}
					}*/

					let last = substr(text, length - 1, 1);
					if ord(last) <= blockSize {

						let paddingSize = last;

						let padding = str_repeat(chr(0), paddingSize - 1) . last;

						//memset(padding, 0, padding_size - 1);
						//padding[padding_size-1] = (unsigned char)padding_size;



						//if (memcmp(padding, str_text + text_len - padding_size, padding_size)) {
						//	padding_size = 0;
						//}
					}

					break;

				case self::PADDING_PKCS7:
					/*if ((unsigned char)(str_text[text_len-1]) <= block_size) {
						padding_size = str_text[text_len-1];

						memset(padding, padding_size, padding_size);

						if (memcmp(padding, str_text + text_len - padding_size, padding_size)) {
							padding_size = 0;
						}
					}*/
					break;

				case self::PADDING_ISO_10126:
					//padding_size = str_text[text_len-1];
					break;

				case self::PADDING_ISO_IEC_7816_4:
					/*i = text_len - 1;
					while (i > 0 && str_text[i] == 0x00 && padding_size < block_size) {
						++padding_size;
						--i;
					}

					padding_size = ((unsigned char)str_text[i] == 0x80) ? (padding_size + 1) : 0;*/
					break;

				case self::PADDING_ZERO:
					/*i = text_len - 1;
					while (i >= 0 && str_text[i] == 0x00 && padding_size <= block_size) {
						++padding_size;
						--i;
					}*/

					break;

				case self::PADDING_SPACE:
					/*i = text_len - 1;
					while (i >= 0 && str_text[i] == 0x20 && padding_size <= block_size) {
						++padding_size;
						--i;
					}*/

					break;

				default:
					break;
			}

			/*if (padding_size && padding_size <= block_size) {
				assert(padding_size <= text_len);
				if (padding_size < text_len) {
					phalcon_substr(return_value, text, 0, text_len - padding_size);
				}
				else {
					ZVAL_EMPTY_STRING(return_value);
				}
			}
			else {
				padding_size = 0;
			}*/
		}

		/*if (!padding_size) {
			ZVAL_ZVAL(return_value, text, 1, 0);
		}*/
	}

	/**
	 * Encrypts a text
	 *
	 *<code>
	 *	$encrypted = $crypt->encrypt("Ultra-secret text", "encrypt password");
	 *</code>
	 *
	 * @param string text
	 * @param string key
	 * @return string
	 */
	public function encrypt(string! text, string! key = null) -> string
	{
		var encryptKey, ivSize, iv, cipher, mode, blockSize, paddingType, padded;

		if !function_exists("mcrypt_get_iv_size") {
			throw new Exception("mcrypt extension is required");
		}

		if key === null {
			let encryptKey = this->_key;
		} else {
			let encryptKey = key;
		}

		if empty encryptKey {
			throw new Exception("Encryption key cannot be empty");
		}

		let cipher = this->_cipher, mode = this->_mode;

		let ivSize = mcrypt_get_iv_size(cipher, mode);

		if strlen(encryptKey) > ivSize {
			throw new Exception("Size of key is too large for this algorithm");
		}

		let iv = mcrypt_create_iv(ivSize, MCRYPT_RAND);
		if typeof iv != "string" {
			let iv = strval(iv);
		}

		let blockSize = mcrypt_get_block_size(cipher, mode);
		if typeof blockSize != "integer" {
			let blockSize = intval(blockSize);
		}

		let paddingType = this->_padding;

		if paddingType != 0 && (mode == "cbc" || mode == "ecb") {
			let padded = this->_cryptPadText(text, mode, blockSize, paddingType);
		} else {
			let padded = text;
		}

		return iv . mcrypt_encrypt(cipher, encryptKey, padded, mode, iv);
	}

	/**
	 * Decrypts an encrypted text
	 *
	 *<code>
	 *	echo $crypt->decrypt($encrypted, "decrypt password");
	 *</code>
	 *
	 * @param string text
	 * @param string key
	 * @return string
	 */
	public function decrypt(string! text, key = null) -> string
	{
		var decryptKey, ivSize, cipher, mode, keySize, length, blockSize, paddingType, decrypted;

		if !function_exists("mcrypt_get_iv_size") {
			throw new Exception("mcrypt extension is required");
		}

		if key === null {
			let decryptKey = this->_key;
		} else {
			let decryptKey = $key;
		}

		if empty decryptKey {
			throw new Exception("Decryption key cannot be empty");
		}

		let cipher = this->_cipher, mode = this->_mode;

		let ivSize = mcrypt_get_iv_size(cipher, mode);

		let keySize = strlen(decryptKey);
		if keySize > ivSize {
			throw new Exception("Size of key is too large for this algorithm");
		}

		let length = strlen(text);
		if keySize > length {
			throw new Exception("Size of IV is larger than text to decrypt");
		}

		let decrypted = mcrypt_decrypt(cipher, decryptKey, substr(text, ivSize), mode, substr(text, 0, ivSize));

		let blockSize = mcrypt_get_block_size(cipher, mode);
		let paddingType = this->_padding;

		if mode == "cbc" || mode == "ecb" {
			return this->_cryptUnpadText(decrypted, mode, blockSize, paddingType);
		}

		return decrypted;
	}

	/**
	 * Encrypts a text returning the result as a base64 string
	 *
	 * @param string text
	 * @param string key
	 * @return string
	 */
	public function encryptBase64(string! text, key=null) -> string
	{
		return base64_encode($this->encrypt(text, key));
	}

	/**
	 * Decrypt a text that is coded as a base64 string
	 *
	 * @param string text
	 * @param string key
	 * @return string
	 */
	public function decryptBase64(string! text, key=null) -> string
	{
		return this->decrypt(base64_decode(text), $key);
	}

	/**
	 * Returns a list of available cyphers
	 *
	 * @return array
	 */
	public function getAvailableCiphers()
	{
		return mcrypt_list_algorithms();
	}

	/**
	 * Returns a list of available modes
	 *
	 * @return array
	 */
	public function getAvailableModes()
	{
		return mcrypt_list_modes();
	}

}