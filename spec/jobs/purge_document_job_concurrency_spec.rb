# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe PurgeDocumentJob do
  self.use_transactional_tests = false

  let!(:document) { create(:document, status: 'deleting') }

  after do
    document.reload.file.purge if document.reload.file.attached?
    Document.where(id: document.id).delete_all
    Member.where(team_id: document.team_id).delete_all
    Team.where(id: document.team_id).delete_all
    User.where(id: document.uploader_id).delete_all
  end

  def worker
    Thread.new do
      ApplicationRecord.connection_pool.with_connection { described_class.perform_now(document.id) }
    end
  end

  it 'permits only one storage purge while another worker holds the document lock' do
    entered = Queue.new
    resume = Queue.new
    service = document.file.blob.service
    allow(service).to receive(:delete).and_wrap_original do |original, *arguments|
      entered << true
      resume.pop
      original.call(*arguments)
    end

    first = worker
    Timeout.timeout(5) { entered.pop }
    second = worker
    expect(second.join(5)).to eq(second)
    expect(document.reload.purge_attempts).to eq(1)
    resume << true
    expect(first.join(5)).to eq(first)
    expect(document.reload.status).to eq('deleted')
  ensure
    allow(service).to receive(:delete).and_call_original if service
    resume << true if resume
    [first, second].compact.each { |thread| thread.join(5) }
  end
end
