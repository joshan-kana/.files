{
  global = {
    check_for_updates_on_startup = false;
    show_in_menu_bar = false;
  };
  profiles = [
    {
      complex_modifications = {
        rules = [
          {
            description = "Mouse actions while in Mouse Mode";
            manipulators = [
              {
                conditions = [
                  {
                    name = "mouse_mode";
                    type = "variable_if";
                    value = 1;
                  }
                ];
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
                type = "basic";
              }
              {
                conditions = [
                  {
                    name = "mouse_mode";
                    type = "variable_if";
                    value = 1;
                  }
                ];
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
                type = "basic";
              }
              {
                conditions = [
                  {
                    name = "mouse_mode";
                    type = "variable_if";
                    value = 1;
                  }
                ];
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
                type = "basic";
              }
            ];
          }
          {
            description = "Toggle Mouse Mode with Globe+Tab";
            manipulators = [
              {
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
                    conditions = [
                      {
                        name = "mouse_mode";
                        type = "variable_if";
                        value = 1;
                      }
                    ];
                    set_variable = {
                      name = "mouse_mode";
                      value = 0;
                    };
                  }
                  {
                    conditions = [
                      {
                        name = "mouse_mode";
                        type = "variable_unless";
                        value = 1;
                      }
                    ];
                    set_variable = {
                      name = "mouse_mode";
                      value = 1;
                    };
                  }
                ];
                type = "basic";
              }
            ];
          }
          {
            description = "Enter is pressed alone, right_command otherwise";
            manipulators = [
              {
                from = {
                  key_code = "right_command";
                  modifiers = {
                    optional = [
                      "any"
                    ];
                  };
                };
                to = [
                  {
                    key_code = "right_command";
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
          {
            description = "Tab is pressed alone, left_command otherwise";
            manipulators = [
              {
                from = {
                  key_code = "left_command";
                  modifiers = {
                    optional = [
                      "any"
                    ];
                  };
                };
                to = [
                  {
                    key_code = "left_command";
                  }
                ];
                to_if_alone = [
                  {
                    key_code = "tab";
                  }
                ];
                type = "basic";
              }
            ];
          }
          {
            description = "Post space is pressed alone, left_option otherwise";
            enabled = false;
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
                    key_code = "left_option";
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
          {
            description = "Post space is pressed alone, left_ctrl otherwise";
            enabled = false;
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
          {
            description = "Caps Lock → Hyper Key (⌃⌥⇧⌘) | Escape if alone | Use fn + caps lock to enable caps lock";
            enabled = false;
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
          {
            description = "right_control + H/J/K/L to Arrow Keys";
            manipulators = [
              {
                from = {
                  key_code = "j";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                      "right_control"
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
                      "right_control"
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
                      "right_control"
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
            description = "right_control + A/E to Home/End";
            enabled = false;
            manipulators = [
              {
                from = {
                  key_code = "a";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                type = "basic";
              }
              {
                from = {
                  key_code = "e";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                type = "basic";
              }
            ];
          }
          {
            description = "right_control + P/N to PageUp/PageDown";
            enabled = false;
            manipulators = [
              {
                from = {
                  key_code = "p";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                type = "basic";
              }
              {
                from = {
                  key_code = "n";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                type = "basic";
              }
            ];
          }
          {
            description = "right_control + B/F to Backspace/Forward Delete; left_control + V/D to delete word/line";
            enabled = false;
            manipulators = [
              {
                from = {
                  key_code = "b";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                type = "basic";
              }
              {
                from = {
                  key_code = "f";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                type = "basic";
              }
              {
                from = {
                  key_code = "v";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                type = "basic";
              }
              {
                from = {
                  key_code = "d";
                  modifiers = {
                    mandatory = [
                      "right_control"
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
                type = "basic";
              }
            ];
          }
          {
            description = "Change semicolon to control if pressed with other keys, to semicolon if pressed alone";
            manipulators = [
              {
                from = {
                  key_code = "semicolon";
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
                    key_code = "semicolon";
                  }
                ];
                type = "basic";
              }
            ];
          }
          {
            description = "Change quote/apostrophe to meh if pressed with other keys, to apostrophe if pressed alone";
            manipulators = [
              {
                from = {
                  key_code = "quote";
                  modifiers = {
                    optional = [
                      "any"
                    ];
                  };
                };
                to = [
                  {
                    key_code = "left_control";
                    modifiers = [
                      "left_shift"
                      "left_option"
                    ];
                  }
                ];
                to_if_alone = [
                  {
                    key_code = "quote";
                  }
                ];
                type = "basic";
              }
            ];
          }
          {
            manipulators = [
              {
                description = "Change caps_lock to command+control+option, escape if pressed alone";
                from = {
                  key_code = "caps_lock";
                  modifiers = {
                    optional = [
                      "any"
                    ];
                  };
                };
                to = [
                  {
                    key_code = "left_command";
                    modifiers = [
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
      devices = [
        {
          identifiers = {
            is_keyboard = true;
            product_id = 50475;
            vendor_id = 1133;
          };
          ignore = true;
        }
        {
          identifiers = {
            is_keyboard = true;
            product_id = 6519;
            vendor_id = 12951;
          };
          ignore = true;
        }
        {
          identifiers = {
            is_keyboard = true;
            product_id = 465;
            vendor_id = 13364;
          };
          ignore = true;
        }
        {
          identifiers = {
            is_keyboard = true;
            product_id = 16452;
            vendor_id = 12346;
          };
          ignore = true;
        }
      ];
      fn_function_keys = [
        {
          from = {
            key_code = "f1";
          };
          to = [
            {
              key_code = "apple_display_brightness_decrement";
            }
          ];
        }
        {
          from = {
            key_code = "f2";
          };
          to = [
            {
              key_code = "apple_display_brightness_increment";
            }
          ];
        }
        {
          from = {
            key_code = "f5";
          };
          to = [
            {
              pointing_button = "button1";
            }
          ];
        }
        {
          from = {
            key_code = "f6";
          };
          to = [
            {
              pointing_button = "button2";
            }
          ];
        }
      ];
      name = "Default profile";
      selected = true;
      virtual_hid_keyboard = {
        keyboard_type_v2 = "ansi";
      };
    }
  ];
}
