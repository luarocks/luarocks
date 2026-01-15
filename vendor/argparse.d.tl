
local record argparse
	type Args = {string : {string} | string | boolean}

	record Parser
		name: function(self: Parser, name: string): Parser
		description: function(self: Parser, description: string): Parser
		epilog: function(self: Parser, epilog: string): Parser

		flag: function(self: Parser, flag: string): Option
		flag: function(self: Parser, shortalias: string, longalias: string): Option

		parse: function(self: Parser, argv: {string}): Args
		pparse: function(self: Parser, argv: {string}): boolean, Args | string

		error: function(self: Parser, error: string)

		argument: function(self: Parser, name: string, description: string): Argument

		get_usage: function(self: Parser): string
		get_help: function(self: Parser): string

		option: function(self: Parser, name: string, description?: string, default?: string, convert?: function | {function}, args?: {string}, count?: integer | string): Option
		option: function(self: Parser, name: string, description?: string, default?: string, convert?: {string:string}, args?: {string}, count?: integer | string): Option

		require_command: function(self: Parser, require_command: boolean): Parser
		command_target: function(self: Parser, command_target: string): Parser

		command: function(self: Parser, name: string, description: string, epilog: string): Command

		add_help: function(self: Parser, boolean)

		help_max_width: function(self: Parser, number): Parser
		add_help_command: function(self: Parser, ?string | {string: any}): Parser
		add_complete_command: function(self: Parser, ?string | {string: any}): Parser

		group: function(self: Parser, ...:any): Parser

		-- TODO: should be Argument | Option
		mutex: function(self: Parser, ...: any)

		record Opts
			name: string
			description: string
			epilog: string
		end
		metamethod __call: function(Parser, Opts): Parser
		metamethod __call: function(Parser, string, string, string): Parser
	end

	type ActionCallback = function(args: Args, index: string, val: string | boolean | {string}, overwrite: boolean)

	record Argument
		choices: function(self: Argument, choices: {string}): Argument

		convert: function(self: Argument, convert: function | {function}): Argument
		convert: function(self: Argument, convert: {string:string}): Argument

		args: function(self: Argument, args: string | integer): Argument

		action: function(self: Argument, cb: ActionCallback)
	end

	record Option
		name: function(self: Option, name: string): Option
		description: function(self: Option, description: string): Option

		argname: function(self: Option, argname: string | {string}): Option

		count: function(self: Option, count: integer | string): Option

		choices: function(self: Option, {string}): Option

		default: function(self: Option, string): Option

		defmode: function(self: Option, string): Option

		target: function(self: Option, target: string): Option

		args: function(self: Option, args: string|integer): Option

		action: function(self: Option, cb: ActionCallback)

		hidden_name: function(self: Option, string)

		hidden: function(self: Option, boolean)

		convert: function(self: Option, function)
	end

	record Command
		summary: function(self: Command, summary: string): Command
		description: function(self: Command, description: string): Command

		argument: function(self: Command, name: string, description?: string): Argument

		option: function(self: Command, name: string, description: string): Option

		flag: function(self: Command, string, ?string): Option

		handle_options: function(self: Command, boolean): Command

		mutex: function(self: Command, ...: any) --! copied over from Parser

		group: function(self: Command, ...:any): Command --! copied over from Parser
	end

	metamethod __call: function(self: argparse, name: string, description: string, epilog: string): Parser
end

return argparse
