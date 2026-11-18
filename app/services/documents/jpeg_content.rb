# frozen_string_literal: true

module Documents
  class JpegContent
    FRAME_MARKERS = [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF].freeze

    # Keep segment boundaries and required frame/scan markers together in this bounded binary parser.
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def self.valid?(bytes)
      return false unless bytes.start_with?("\xFF\xD8\xFF".b) && bytes.end_with?("\xFF\xD9".b)

      offset = 2
      has_frame = false
      4096.times do
        segment = read_segment(bytes, offset)
        return false unless segment

        marker, data, ending = segment
        return has_frame && data.bytesize >= 4 && ending < bytes.bytesize - 2 if marker == 0xDA

        has_frame ||= FRAME_MARKERS.include?(marker) && valid_frame?(data)
        offset = ending
      end
      false
    end

    def self.valid_frame?(data)
      return false if data.bytesize < 6

      height, width = data.byteslice(1, 4).unpack('nn')
      width.positive? && height.positive? && width * height <= 40_000_000
    end

    # :reek:DuplicateMethodCall -- The cursor advances between byte reads while skipping marker padding.
    def self.read_segment(bytes, offset)
      return unless bytes.getbyte(offset) == 0xFF

      offset += 1 while bytes.getbyte(offset) == 0xFF
      marker = bytes.getbyte(offset)
      return unless marker && offset + 3 <= bytes.bytesize

      length = bytes.byteslice(offset + 1, 2).unpack1('n')
      ending = offset + 1 + length
      return if length < 2 || ending > bytes.bytesize

      [marker, bytes.byteslice(offset + 3, length - 2), ending]
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
  end
end
