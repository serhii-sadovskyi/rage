# frozen_string_literal: true

##
# The collection of dead tasks: tasks that used up or aborted their retries. Use {Rage::Deferred.dead_tasks} to get it.
#
# The class includes `Enumerable`, so `map`, `select`, `count`, `to_a`, and the other methods work through {#each}.
# Every one of them reads the whole dead-tasks store.
#
# @example List dead tasks
#   Rage::Deferred.dead_tasks.each do |task|
#     puts "#{task.task_class}: #{task.exception_message}"
#   end
#
# @example Find a dead task
#   task = Rage::Deferred.dead_tasks.find_by_id("1759312800-4242-7")
#   task.args # => [42]
#
class Rage::Deferred::DeadTasks
  include Enumerable

  # @private
  def initialize(backend)
    @__backend = backend
  end

  # Yield every dead task, oldest first: in the order in which the tasks became dead.
  #
  # The set of tasks is fixed when the call starts. A task that becomes dead after that is not yielded by this call,
  # and a task that is removed after that is still yielded. Every new call reads the store again.
  #
  # The method reads the whole dead-tasks store twice, so its cost grows with the size of the store. It holds
  # one task in memory at a time.
  #
  # @yieldparam task [Rage::Deferred::DeadTask]
  # @return [self, Enumerator] the collection, or an `Enumerator` if no block is given
  # @raise [Rage::Deferred::DeadTasksLockTimeout] if the dead-tasks store cannot be locked
  # @example
  #   Rage::Deferred.dead_tasks.each do |task|
  #     puts "#{task.id} failed with #{task.exception_class}"
  #   end
  # @example Without a block
  #   Rage::Deferred.dead_tasks.each.with_index { |task, i| puts "#{i}: #{task.id}" }
  def each
    return to_enum(:each) unless block_given?

    @__backend.each_dead_task { |record| yield Rage::Deferred::DeadTask.new(record) }

    self
  end

  # Find a dead task by its id.
  #
  # The method reads the whole dead-tasks store, so its cost grows with the size of the store.
  #
  # @param id [String] the id of the task
  # @return [Rage::Deferred::DeadTask, nil] the dead task, or `nil` if there is no dead task with this id
  # @raise [Rage::Deferred::DeadTasksLockTimeout] if the dead-tasks store cannot be locked
  # @example
  #   task = Rage::Deferred.dead_tasks.find_by_id("1759312800-4242-7")
  #   task.exception_message if task
  def find_by_id(id)
    record = @__backend.find_dead_task(id)
    Rage::Deferred::DeadTask.new(record) if record
  end
end
