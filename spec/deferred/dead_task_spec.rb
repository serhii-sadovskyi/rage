# frozen_string_literal: true

RSpec.describe "Rage::Deferred::DeadTask" do
  let(:storage_path) { Pathname.new(Dir.mktmpdir) }
  let(:backend) { Rage::Deferred::Backends::Disk.new(path: storage_path, prefix: "test_prefix", fsync_frequency: 100) }
  let(:dead_tasks) { Rage::Deferred::DeadTasks.new(backend) }

  after do
    FileUtils.remove_entry(storage_path)
  end

  def raised_exception(message = "boom")
    raise message
  rescue => e
    e
  end

  it "returns the stored id, class name, attempts, enqueue time, failure time, exception class, exception message, and backtrace" do
    exception = raised_exception("boom")
    backend.add_dead_task("1700000000-99-3", ["SendWelcomeEmail", nil, nil, 0], exception, task_class: "SendWelcomeEmail", attempts: 21)
    record = backend.find_dead_task("1700000000-99-3")

    task = dead_tasks.find_by_id("1700000000-99-3")

    expect(task).to be_a(Rage::Deferred::DeadTask)
    expect(task.id).to eq("1700000000-99-3")
    expect(task.task_class).to eq("SendWelcomeEmail")
    expect(task.attempts).to eq(21)
    expect(task.enqueued_at).to eq(Time.at(1700000000))
    expect(task.failed_at).to eq(Time.at(record[:failed_at]))
    expect(task.exception_class).to eq("RuntimeError")
    expect(task.exception_message).to eq("boom")
    expect(task.backtrace).to eq(record[:backtrace])
    expect(task.backtrace.first).to eq(exception.backtrace.first)
  end

  it "returns the positional and keyword arguments the task was enqueued with" do
    context = ["SendWelcomeEmail", [42, "welcome"], { email: "user@example.com" }, 0]
    backend.add_dead_task("1-1-1", context, RuntimeError.new("boom"), task_class: "SendWelcomeEmail", attempts: 3)

    task = dead_tasks.find_by_id("1-1-1")

    expect(task).to be_a(Rage::Deferred::DeadTask)
    expect(task.args).to eq([42, "welcome"])
    expect(task.kwargs).to eq({ email: "user@example.com" })
  end

  it "returns empty collections for a task enqueued without arguments" do
    backend.add_dead_task("1-1-1", ["SendWelcomeEmail", nil, nil, 0], RuntimeError.new("boom"), task_class: "SendWelcomeEmail", attempts: 3)

    task = dead_tasks.find_by_id("1-1-1")

    expect(task.args).to eq([])
    expect(task.kwargs).to eq({})
  end

  it "raises ArgumentError from args if a class of the stored context no longer exists" do
    stub_const("VanishedTask", Class.new)
    backend.add_dead_task("1-1-1", [VanishedTask, [42], nil, 0], RuntimeError.new("boom"), task_class: "VanishedTask", attempts: 3)
    hide_const("VanishedTask")

    task = dead_tasks.find_by_id("1-1-1")

    expect { task.args }.to raise_error(ArgumentError)
  end
end
