# frozen_string_literal: true

require 'zlib'

module Documents
  class PngContent
    # Keep bounds, CRC and terminator checks together in this bounded binary parser.
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def self.valid?(bytes)
      return false unless valid_header?(bytes)

      offset = 8
      has_pixels = false
      4096.times do
        chunk = read_chunk(bytes, offset)
        return false unless chunk

        type, data, ending = chunk
        return ending == bytes.bytesize && data.empty? && has_pixels if type == 'IEND'
        return false if type == 'IHDR' && offset != 8

        has_pixels ||= type == 'IDAT' && data.present?
        offset = ending
      end
      false
    end

    def self.valid_header?(bytes)
      return false unless bytes.start_with?("\x89PNG\r\n\x1A\n".b) && bytes.bytesize >= 45
      return false unless bytes.byteslice(8, 8) == "\x00\x00\x00\x0DIHDR".b

      width, height = bytes.byteslice(16, 8).unpack('NN')
      width.positive? && height.positive? && width * height <= 40_000_000
    end

    def self.read_chunk(bytes, offset)
      size = bytes.bytesize
      return if offset + 12 > size

      length = bytes.byteslice(offset, 4).unpack1('N')
      ending = offset + length + 12
      return if ending > size

      type = bytes.byteslice(offset + 4, 4)
      data_offset = offset + 8
      data = bytes.byteslice(data_offset, length)
      crc = bytes.byteslice(data_offset + length, 4).unpack1('N')
      return unless Zlib.crc32(type + data) == crc

      [type, data, ending]
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  end
end
