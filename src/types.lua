--- @alias Mode
--- | 'ide'
--- | 'play'
--- | 'test'
--- | 'harmony'
--- @alias Testflags { auto: boolean?, draw: boolean?, size: boolean? }

--- @class Start
--- @field mode Mode
--- @field testflags Testflags?
--- @field path string?

--- @class PathInfo table
--- @field storage_path string
--- @field project_path string
--- @field play_path string

--- @class CursorInfo table
--- @field cursor Cursor

---@alias VerticalDir
---| 'up'
---| 'down'

---@alias InputType
---| 'lua'
---| 'text'

---@alias ContentType
---| 'plain'
---| 'lua'
---| 'md'

---@alias Fac # scaling
---| 1
---| 2

--- @class ViewConfig table
--- @field font love.Font
--- @field iconfont love.Font
--- @field fh integer -- font height
--- @field fw integer -- font width
--- @field lh integer -- line height
--- @field lines integer
--- @field input_max integer
--- @field show_append_hl boolean
--- @field show_debug_timer boolean
--- @field labelfont love.Font
--- @field lfh integer -- font height
--- @field lfw integer -- font width
--- @field h integer
--- @field w integer
--- @field colors Colors
--- @field debugheight integer
--- @field debugwidth integer
--- @field drawableWidth number
--- @field drawableChars integer
--- @field drawtest boolean
--- @field sizedebug boolean

--- @class Config table
--- @field view ViewConfig
--- @field autotest boolean
--- @field mode Mode

--- @alias More {up: boolean, down: boolean}

--- @class Status table
--- @field label string
--- @field cursor Cursor?
--- @field n_lines integer
--- @field input_more More
--- @field custom CustomStatus?

--- @class InputDTO table
--- @field text InputText
--- @field highlight Highlight
--- @field wrapped_error string[]
--- @field selection InputSelection
--- @field visible VisibleContent

--- @class ViewData table
--- @field w_error string[]

--- @class Highlight table
--- @field parse_err Error?
--- @field hl SyntaxColoring

--- @alias TokenType
--- | 'kw_single'
--- | 'kw_multi'
--- | 'number'
--- | 'string'
--- | 'identifier'

--- @alias LexType
--- | TokenType
--- | 'comment'
--- | 'error'

--- @class UserInput table
--- @field M UserInputModel
--- @field V UserInputView
--- @field C UserInputController

--- @alias AppState
--- | 'starting'
--- | 'title'
--- | 'ready'
--- | 'project_open'
--- | 'editor'
--- | 'running'
--- | 'inspect'
--- | 'shutdown'

--- @class BufferState table
--- @field filename string
--- @field selection integer
--- @field offset integer

--- @class EditorState table
--- @field buffer BufferState
--- @field clipboard string?
--- @field moved integer?

--- @class LoveState table
--- @field testing boolean
--- @field has_removable boolean
--- @field user_input UserInput?
--- @field app_state AppState
--- @field prev_state AppState?
--- @field editor EditorState?

--- @class LoveDebug table
--- @field show_snapshot boolean
--- @field show_terminal boolean
--- @field show_canvas boolean
--- @field show_input boolean
--- @field once integer

--- @class LuaEnv : table

--- @class ResultsDTO table
--- @field results table[]
--- @field selection integer


--- @alias ParseResult<T> T|Error

--- @alias Chunker fun(s: string[], integer, boolean?): boolean, Block[], ParseResult
--- @alias Highlighter fun(c: str): SyntaxColoring
--- @alias Printer fun(c: string[], integer?): string[]?

--- @class Parser
--- @field parse fun(code: string[]): ParseResult
--- @field chunker Chunker
--- @field pprint Printer?
---
--- @field tokenize fun(str): table
--- @field syntax_hl fun(table): SyntaxColoring
