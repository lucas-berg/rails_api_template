# frozen_string_literal: true

module Documents
  class InspectContent
    class Invalid < StandardError; end

    def self.call(document)
      document.file.blob.open do |file|
        check_size!(file.size, document.byte_size)
        detected = detect_type!(file, document.declared_content_type)
        file.rewind
        check_structure!(file.read, detected)
        detected
      end
    end

    # :reek:ControlParameter -- Stored metadata must agree with actual bytes.
    def self.check_size!(actual, expected)
      return if actual == expected && actual.positive? && actual <= Document.maximum_bytes

      raise Invalid, 'file_size_mismatch'
    end

    # :reek:ControlParameter -- The declared type is checked, never trusted as a detector hint.
    def self.detect_type!(file, declared_type)
      detected = Marcel::MimeType.for(file)
      return detected if detected == declared_type && Document::CONTENT_TYPES.include?(detected)

      raise Invalid, 'file_type_mismatch'
    end

    # :reek:ControlParameter -- Dispatch is limited to the detected allowlisted formats.
    def self.check_structure!(bytes, content_type)
      valid = case content_type
              when 'image/png' then PngContent.valid?(bytes)
              when 'image/jpeg' then JpegContent.valid?(bytes)
              when 'application/pdf' then valid_pdf?(bytes)
              end
      raise Invalid, 'invalid_file_content' unless valid
    end

    def self.valid_pdf?(bytes)
      bytes.start_with?('%PDF-') && bytes.rstrip.end_with?('%%EOF')
    end
  end
end
