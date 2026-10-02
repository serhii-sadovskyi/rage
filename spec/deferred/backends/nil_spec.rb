# frozen_string_literal: true

RSpec.describe Rage::Deferred::Backends::Nil do
  subject(:backend) { described_class.new }

  describe "#each_dead_task" do
    it "never calls the block" do
      yielded = []

      result = backend.each_dead_task { |record| yielded << record }

      expect(yielded).to eq([])
      expect(result).to be_nil
    end
  end
end
