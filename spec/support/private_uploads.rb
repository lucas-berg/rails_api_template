# frozen_string_literal: true

module PrivateUploads
  def png_bytes
    Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==')
  end

  def pdf_bytes
    "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n"
  end

  def jpeg_bytes
    Rails.root.join('spec/fixtures/files/sample.jpg').binread
  end

  def multipart_upload(bytes = png_bytes, content_type: 'image/png', filename: 'sample.png')
    Rack::Test::UploadedFile.new(StringIO.new(bytes), content_type, true, original_filename: filename)
  end
end

RSpec.configure do |config|
  config.include PrivateUploads
end
