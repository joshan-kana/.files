{
  caps-lock-hyper = {
    title = "Caps Lock → Hyper Key (⌃⌥⇧⌘) (Escape if alone)";
    rules = [
      {
        description = "Caps Lock → Hyper Key (⌃⌥⇧⌘) | Escape if alone | Use fn + caps lock to enable caps lock";
        manipulators = [
          {
            from = {
              key_code = "caps_lock";
            };
            to = [
              {
                key_code = "left_shift";
                modifiers = [
                  "left_command"
                  "left_control"
                  "left_option"
                ];
              }
            ];
            to_if_alone = [
              {
                key_code = "escape";
              }
            ];
            type = "basic";
          }
        ];
      }
    ];
  };
  return-control = {
    title = "Change return to control";
    rules = [
      {
        description = "Change return to control if pressed with other keys, to return if pressed alone";
        manipulators = [
          {
            from = {
              key_code = "return_or_enter";
              modifiers = {
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "right_control";
              }
            ];
            to_if_alone = [
              {
                key_code = "return_or_enter";
              }
            ];
            type = "basic";
          }
        ];
      }
    ];
  };
  option-navigation = {
    title = "Map Left Option plus h/j/k/l to Arrows";
    rules = [
      {
        description = "Map Left Option plus h/j/k/l to Arrows";
        manipulators = [
          {
            type = "basic";
            from = {
              key_code = "h";
              modifiers = {
                mandatory = [
                  "left_option"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "left_arrow";
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "j";
              modifiers = {
                mandatory = [
                  "left_option"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "down_arrow";
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "k";
              modifiers = {
                mandatory = [
                  "left_option"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "up_arrow";
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "l";
              modifiers = {
                mandatory = [
                  "left_option"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "right_arrow";
              }
            ];
          }
        ];
      }
    ];
  };
  control-navigation = {
    title = "Left Control to Navigate";
    rules = [
      {
        description = "left_control + H/J/K/L to Arrow Keys";
        manipulators = [
          {
            from = {
              key_code = "j";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "down_arrow";
              }
            ];
            type = "basic";
          }
          {
            from = {
              key_code = "k";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "up_arrow";
              }
            ];
            type = "basic";
          }
          {
            from = {
              key_code = "h";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "left_arrow";
              }
            ];
            type = "basic";
          }
          {
            from = {
              key_code = "l";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "right_arrow";
              }
            ];
            type = "basic";
          }
        ];
      }
      {
        description = "left_control + A/E to Home/End";
        manipulators = [
          {
            type = "basic";
            from = {
              key_code = "a";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "home";
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "e";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "end";
              }
            ];
          }
        ];
      }
      {
        description = "left_control + P/N to PageUp/PageDown";
        manipulators = [
          {
            type = "basic";
            from = {
              key_code = "p";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "page_up";
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "n";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "page_down";
              }
            ];
          }
        ];
      }
      {
        description = "left_control + B/F to Backspace/Forward Delete; left_control + V/D to delete word/line";
        manipulators = [
          {
            type = "basic";
            from = {
              key_code = "b";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "delete_or_backspace";
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "f";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "delete_forward";
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "v";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "delete_or_backspace";
                modifiers = [
                  "left_option"
                ];
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "d";
              modifiers = {
                mandatory = [
                  "left_control"
                ];
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "delete_or_backspace";
                modifiers = [
                  "left_command"
                ];
              }
            ];
          }
        ];
      }
    ];
  };
  spacebar-control = {
    title = "Spacebar changes";
    rules = [
      {
        description = "Post space is pressed alone, left_ctrl otherwise";
        manipulators = [
          {
            from = {
              key_code = "spacebar";
              modifiers = {
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                key_code = "left_control";
              }
            ];
            to_if_alone = [
              {
                key_code = "spacebar";
              }
            ];
            type = "basic";
          }
        ];
      }
    ];
  };
  mouse-mode = {
    title = "Mouse Mode (Globe+Tab toggle)";
    rules = [
      {
        description = "Toggle Mouse Mode with Globe+Tab";
        manipulators = [
          {
            type = "basic";
            from = {
              key_code = "tab";
              modifiers = {
                mandatory = [
                  "fn"
                ];
              };
            };
            to_if_alone = [
              {
                set_variable = {
                  name = "mouse_mode";
                  value = 0;
                };
                conditions = [
                  {
                    type = "variable_if";
                    name = "mouse_mode";
                    value = 1;
                  }
                ];
              }
              {
                set_variable = {
                  name = "mouse_mode";
                  value = 1;
                };
                conditions = [
                  {
                    type = "variable_unless";
                    name = "mouse_mode";
                    value = 1;
                  }
                ];
              }
            ];
          }
        ];
      }
      {
        description = "Mouse actions while in Mouse Mode";
        manipulators = [
          {
            type = "basic";
            from = {
              key_code = "escape";
              modifiers = {
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                pointing_button = "button1";
              }
            ];
            conditions = [
              {
                type = "variable_if";
                name = "mouse_mode";
                value = 1;
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "f1";
              modifiers = {
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                pointing_button = "button3";
              }
            ];
            conditions = [
              {
                type = "variable_if";
                name = "mouse_mode";
                value = 1;
              }
            ];
          }
          {
            type = "basic";
            from = {
              key_code = "f2";
              modifiers = {
                optional = [
                  "any"
                ];
              };
            };
            to = [
              {
                pointing_button = "button2";
              }
            ];
            conditions = [
              {
                type = "variable_if";
                name = "mouse_mode";
                value = 1;
              }
            ];
          }
        ];
      }
    ];
  };
}
