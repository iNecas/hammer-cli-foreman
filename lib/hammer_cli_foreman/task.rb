require 'powerbar'

module HammerCLIForeman

  class Task < HammerCLI::AbstractCommand

    class ProgressCommand < ReadCommand

      command_name "progress"
      desc "Show the progress of the task"

      option '--id', "UUID", "UUID of the task", :required => true

      class TaskProgress

        attr_accessor :interval, :task

        def initialize(task_id, &block)
          @update_block = block
          @task_id      = task_id
          @interval     = 2
        end

        def render
          update_task
          if task_pending?
            render_progress
          else
            render_result
          end
        end

        private

        def render_progress
          progress_bar do |bar|
            while true
              bar.show(:msg => "Task #{@task_id} progress", :done => @task['progress'].to_f, :total => 1)
              if task_pending?
                sleep interval
                update_task
              else
                render_result
                break
              end
            end
          end
        end

        def render_result
          puts "Task #{@task_id} #{@task['result']}"
          unless @task['humanized']['output'].to_s.empty?
            puts @task['humanized']['output']
          end
        end

        def update_task
          @task = @update_block.call(@task_id)
        end

        def task_pending?
          !%w[paused stopped].include?(@task['state'])
        end

        def progress_bar
          bar                                      = PowerBar.new
          bar.settings.tty.finite.template.main    = '[${<bar>}] [${<percent>%}]'
          bar.settings.tty.finite.template.padchar = ' '
          bar.settings.tty.finite.template.barchar = '.'
          bar.settings.tty.finite.output           = Proc.new { |s| $stderr.print s }
          yield bar
        ensure
          bar.close
        end
      end

      def execute
        @task = demo_task
        task_progress
        HammerCLI::EX_OK
      end

      def task_progress
        TaskProgress.new(@task['id']) { |task_id| load_task(task_id) }.tap do |task_progress|
          task_progress.render
        end
      end

      def load_task(id)
        client = ForemanApi::Base.new(resource_config)
        client.http_call(:get, "/dyntask/api/tasks/#{id}").first.values.first
      end

      def demo_task
        client = ForemanApi::Base.new(resource_config)
        data = {:commands => ["/home/inecas/Projects/dynflow/sysflow/bin/cmd_demo"] * 3 }
        client.http_call(:post, "/commands.json", data).first.values.first
      end

    end

    autoload_subcommands
  end
end

HammerCLI::MainCommand.subcommand 'task', "Tasks related actions.", HammerCLIForeman::Task

