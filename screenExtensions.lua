-- Extension to augment the Norns Screen functions

------------------------ screen.current_font_size() -------------------

-- Modify font_size() so that it stores the font size
local _original_font_size_function = screen.font_size
local _current_font_size

screen.font_size = function(size)
  _current_font_size = size
  _original_font_size_function(size)
end

-- Extension. Returns the current font size
screen.current_font_size = function()
  return _current_font_size
end

------------------------ screen.current_font_face() -------------------

-- Modify font_face() so that it stores the font face
local _original_font_face_function = screen.font_face
local _current_font_face

screen.font_face = function(face)
  _current_font_face = face
  _original_font_face_function(face)
end

-- Extension. Returns the current font face
screen.current_font_face = function()
  return _current_font_face
end

----------------------- screen.aa() anti-aliasing ---------------------

-- Modify font_aa() so that it stores the anti-aliasing state
local _original_aa_function = screen.aa
local _current_aa

screen.aa = function(on)
  _current_aa = on
  _original_aa_function(on)
end

-- Extension. Returns the current anti-aliasing
screen.current_aa = function()
  return _current_aa
end
