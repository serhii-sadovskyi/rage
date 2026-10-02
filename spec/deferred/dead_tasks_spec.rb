# frozen_string_literal: true

RSpec.describe "Rage::Deferred::DeadTasks" do
  let(:storage_path) { Pathname.new(Dir.mktmpdir) }
  let(:backend) { Rage::Deferred::Backends::Disk.new(path: storage_path, prefix: "test_prefix", fsync_frequency: 100) }
  let(:dead_tasks) { Rage::Deferred::DeadTasks.new(backend) }

  after do
    FileUtils.remove_entry(storage_path)
  end

  def add_dead_task(task_id, context: ["SendWelcomeEmail", [], {}, 0], task_class: "SendWelcomeEmail")
    backend.add_dead_task(task_id, context, RuntimeError.new("boom"), task_class:, attempts: 3)
  end

  describe "#each" do
    it "yields one DeadTask per stored record, oldest first" do
      add_dead_task("1-1-1")
      add_dead_task("2-2-2")
      add_dead_task("3-3-3")
      yielded = []

      dead_tasks.each { |task| yielded << task }

      expect(yielded).to all(be_a(Rage::Deferred::DeadTask))
      expect(yielded.map(&:id)).to eq(["1-1-1", "2-2-2", "3-3-3"])
    end

    it "still yields a DeadTask when the task class of the record no longer exists" do
      stub_const("VanishedTask", Class.new)
      add_dead_task("1-1-1", context: [VanishedTask, [42], nil, 0], task_class: "VanishedTask")
      hide_const("VanishedTask")
      yielded = []

      dead_tasks.each { |task| yielded << task }

      expect(yielded.map { |task| [task.class, task.id, task.task_class] }).to eq(
        [[Rage::Deferred::DeadTask, "1-1-1", "VanishedTask"]]
      )
    end

    it "returns the record from find_by_id called inside the block of each" do
      add_dead_task("1-1-1")
      add_dead_task("2-2-2")
      found = []

      dead_tasks.each { |task| found << dead_tasks.find_by_id(task.id) }

      expect(found).to all(be_a(Rage::Deferred::DeadTask))
      expect(found.map(&:id)).to eq(["1-1-1", "2-2-2"])
    end

    it "returns an Enumerator over the same records without a block" do
      add_dead_task("1-1-1")
      add_dead_task("2-2-2")

      enumerator = dead_tasks.each

      expect(enumerator).to be_an(Enumerator)
      expect(enumerator.map(&:id)).to eq(["1-1-1", "2-2-2"])
    end

    it "does not yield a dead task added while the block runs" do
      add_dead_task("1-1-1")
      add_dead_task("2-2-2")
      yielded = []

      dead_tasks.each do |task|
        add_dead_task("3-3-3") if yielded.empty?
        yielded << task.id
      end

      expect(yielded).to eq(["1-1-1", "2-2-2"])
    end

    it "yields one DeadTask for two records with the same task id" do
      add_dead_task("1-1-1")
      add_dead_task("2-2-2")
      add_dead_task("1-1-1")

      expect(dead_tasks.map(&:id)).to eq(["2-2-2", "1-1-1"])
    end

    it "raises DeadTasksLockTimeout if the lock of the store cannot be taken" do
      add_dead_task("1-1-1")
      yielded = []

      File.open(storage_path.join("test_prefixdead_tasks.lock"), File::RDWR) do |lock_file|
        lock_file.flock(File::LOCK_EX)

        expect {
          dead_tasks.each { |task| yielded << task }
        }.to raise_error(Rage::Deferred::DeadTasksLockTimeout)
      end

      expect(yielded).to eq([])
    end

    context "with the Nil backend" do
      let(:backend) { Rage::Deferred::Backends::Nil.new }

      it "yields nothing and returns the collection" do
        yielded = []

        result = dead_tasks.each { |task| yielded << task }

        expect(yielded).to eq([])
        expect(result).to equal(dead_tasks)
      end
    end
  end

  describe "#find_by_id" do
    it "returns nil for an id that is not in the store" do
      add_dead_task("1-1-1")

      expect(dead_tasks.find_by_id("2-2-2")).to be_nil
    end

    context "with the Nil backend" do
      let(:backend) { Rage::Deferred::Backends::Nil.new }

      it "returns nil" do
        expect(dead_tasks.find_by_id("1-1-1")).to be_nil
      end
    end
  end
end
