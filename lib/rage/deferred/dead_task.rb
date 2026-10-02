# frozen_string_literal: true

##
# A dead task: a task that used up or aborted its retries. Instances are returned by {Rage::Deferred::DeadTasks}.
#
# @example
#   task = Rage::Deferred.dead_tasks.find_by_id("1759312800-4242-7")
#
#   task.task_class        # => "SendWelcomeEmail"
#   task.attempts          # => 21
#   task.exception_class   # => "Net::ReadTimeout"
#   task.exception_message # => "Net::ReadTimeout with #<TCPSocket:(closed)>"
#   task.kwargs            # => { email: "user@example.com" }
#
class Rage::Deferred::DeadTask
  # @return [String] the id of the task
  attr_reader :id

  # @return [String] the name of the task class; the class itself may no longer exist
  attr_reader :task_class

  # @return [Integer] the number of attempts made to process the task
  attr_reader :attempts

  # @return [String] the class name of the exception raised during the last attempt
  attr_reader :exception_class

  # @return [String] the message of the exception raised during the last attempt
  attr_reader :exception_message

  # @return [Array<String>] the backtrace of the exception raised during the last attempt
  attr_reader :backtrace

  # @private
  # @param record [Hash] the Hash the backend returns for one dead task
  def initialize(record)
    @id = record[:id]
    @task_class = record[:task_class]
    @attempts = record[:attempts]
    @exception_class = record[:exception_class]
    @exception_message = record[:exception_message]
    @backtrace = record[:backtrace]
    @__enqueued_at = record[:enqueued_at]
    @__failed_at = record[:failed_at]
    @__serialized_context = record[:context]
  end

  # @return [Time] the time the task was enqueued
  # @example
  #   task.enqueued_at # => 2026-10-01 10:00:00 +0000
  def enqueued_at
    Time.at(@__enqueued_at)
  end

  # @return [Time] the time the task became dead
  # @example
  #   task.failed_at # => 2026-10-01 12:30:00 +0000
  def failed_at
    Time.at(@__failed_at)
  end

  # The positional arguments the task was enqueued with. For a task enqueued with {Rage::Deferred.wrap}, the list
  # starts with the wrapped object and the method name.
  #
  # @return [Array] the arguments, or an empty Array if the task had none
  # @raise [ArgumentError] if the arguments cannot be decoded, for example because a class no longer exists
  # @example
  #   task.args # => [42]
  def args
    Rage::Deferred::Context.get_args(__context) || []
  end

  # The keyword arguments the task was enqueued with.
  #
  # @return [Hash] the keyword arguments, or an empty Hash if the task had none
  # @raise [ArgumentError] if the arguments cannot be decoded, for example because a class no longer exists
  # @example
  #   task.kwargs # => { email: "user@example.com" }
  def kwargs
    Rage::Deferred::Context.get_kwargs(__context) || {}
  end

  private

  def __context
    @__context ||= Marshal.load(@__serialized_context)
  end
end
