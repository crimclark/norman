-- |*| |*|
--   0   -- "We are Norm"
--
-- -------------------------------
-- Simple audio utility using SoX
--
-- Before you start:
--
-- SSH into Norns and run
-- sudo apt-get update
-- sudo apt-get install sox
--
-- Controls:
--
-- E2 : Scroll Params
-- E3 : Change Param
-- K3 : Process File

local FileSelect = require 'fileselect'

local NORMALIZE, TRIM, OVERWRITE = 'normalize', 'trim silence', 'overwrite'
local menu = { NORMALIZE, TRIM, OVERWRITE }
menu.activeIndex = 1

local screenLevels = { BRIGHT = 15, MEDIUM = 6, DIM = 1 }

local YES, NO = 'yes', 'no'

local MAIN_VIEW, NOTIFICATION_VIEW = 'main', 'notification'
local views, encoderHandlers, controlHandlers = {}, {}, {}

controlHandlers.__index = function(_, key)
  return function()
    print('handler not implemented for control ' .. key)
  end
end

function create_views()
  local mainView = {}
  mainView.keyHandlers = { nil, nil, select_process_file }
  setmetatable(mainView.keyHandlers, controlHandlers)

  local notificationView = {}
  notificationView.keyHandlers = { nil, nil, select_ok }
  setmetatable(notificationView.keyHandlers, controlHandlers)

  views[MAIN_VIEW] = mainView
  views[NOTIFICATION_VIEW] = notificationView
  views.active = MAIN_VIEW
end

function create_encoder_handlers()
  local handlers = { nil, select_new_param, update_param }
  setmetatable(handlers, controlHandlers)
  encoderHandlers = handlers
end

function init()
  add_params()
  create_views()
  create_encoder_handlers()
  show_main_view()
end

function add_params()
  for _,value in ipairs(menu) do
    local default = value == NORMALIZE and 2 or 1
    params:add_option(value, value, { NO, YES }, default)
  end
end

function redraw()
  screen.clear()
  draw_menu(menu)
  draw_process_file(screenLevels.BRIGHT)
end

function draw_process_file(screenLevel)
  screen.move(75,60)
  screen.level(screenLevel)
  screen.text('Process File')
  screen.update()
end

function draw_menu(options)
  screen.level(screenLevels.MEDIUM)
  local y = 10
  for i,value in ipairs(options) do
    if menu.activeIndex == i then
      screen.level(screenLevels.BRIGHT)
    end
    screen.move(0, y)
    screen.text(value .. ': ')
    screen.move(110, y)
    screen.text(params:string(i))
    y = y + 10
    screen.level(screenLevels.MEDIUM)
  end
end

function is_yes(paramIndex)
  return params:string(paramIndex) == YES
end

function build_output(path)
  if is_yes(OVERWRITE) then return path end
  local extension = path:match('.wav') or path:match('.aif')
  return path:gsub(extension, '_norman' .. extension)
end

function build_cmd(input, output)
  local normalize = is_yes(NORMALIZE)
  local trim = is_yes(TRIM)
  if not normalize and not trim then return '' end

  local command = 'sox ' .. input .. ' ' .. output

  if normalize then
    command = command .. ' norm -1.0'
  end

  if trim then
    command = command .. ' silence 1 0.1 1%'
  end

  return command
end

function fileselect_callback(path)
  if path == 'cancel' then return end

  if not path:find('.aif') and not path:find('.wav') then
    return show_error_view('Invalid file type')
  end

  local output = build_output(path)
  local command = build_cmd(path, output)
  if #command == 0 then return end

  print('executing command: ' .. command)
  local error = util.os_capture(command)

  if #error > 0 then
    print(error)
    return show_error_view(error)
  end

  if not util.file_exists(output) then
    return show_error_view('Unknown error creating file')
  end

  show_success_view(output)
end

function show_main_view()
  redraw()
  views.active = MAIN_VIEW
end

function show_success_view(output)
  draw_success(output)
  views.active = NOTIFICATION_VIEW
end

function show_error_view(error)
  draw_error(error)
  views.active = NOTIFICATION_VIEW
end

function draw_error(error)
  screen.clear()
  screen.move(60,10)
  screen.text_center(error)
  draw_ok(screenLevels.BRIGHT)
end

function select_process_file(z)
  select_button(draw_process_file, z, select_file)
end

function select_ok(z)
  select_button(draw_ok, z, show_main_view)
end

function select_button(draw, z, callback)
  draw(screenLevels.DIM)
  if (z == 0) then callback() end
end

function key(num, z)
  local activeView = views.active
  views[activeView].keyHandlers[num](z)
end

function select_new_param(delta)
  local newIndex = menu.activeIndex + util.clamp(delta, -1, 1)
  menu.activeIndex = util.clamp(newIndex, 1, 3)
  redraw()
end

function update_param(delta)
  local activeIndex = menu.activeIndex
  local currentValue = params:get(activeIndex)
  local newValue = util.clamp(currentValue + delta, 1, 2)
  params:set(activeIndex, newValue)
  redraw()
end

function enc(num, delta)
  encoderHandlers[num](delta)
end

function draw_ok(screenLevel)
  screen.level(screenLevel)
  screen.move(60, 60)
  screen.text_center('OK')
  screen.update()
end

function draw_success(output)
  local filename = output:match('^.*%/(.*)')
  local x, y = 60, 10
  screen.clear()
  screen.level(screenLevels.BRIGHT)
  screen.move(x, y)
  screen.text_center('Success!')
  y = y + 20
  screen.level(screenLevels.MEDIUM)
  screen.move(x, y)
  screen.text_center('created:')
  y = y + 10
  screen.move(x, y)
  screen.text_center(filename)
  y = y + 20
  draw_ok(screenLevels.BRIGHT)
end

function select_file()
  FileSelect.enter(_path.audio, fileselect_callback)
end

-- todo test trim silence
-- todo test behavior of large file
