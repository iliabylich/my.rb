require_relative './locals'

require_relative './helpers/method_definition_scope'
require_relative './helpers/constant_definition_scope'
require_relative './helpers/backtrace_entry'

require_relative './stack'

require_relative './frames/factory'
require_relative './frames/top_frame'
require_relative './frames/class_frame'
require_relative './frames/module_frame'
require_relative './frames/sclass_frame'
require_relative './frames/method_frame'
require_relative './frames/block_frame'
require_relative './frames/ensure_frame'
require_relative './frames/rescue_frame'
require_relative './frames/eval_frame'

require_relative './frame_stack'
