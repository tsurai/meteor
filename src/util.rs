use std::fs::File;
use std::io::Read;
use regex::Regex;
use rlua::Lua;
use log::LogLevel;
use failure::*;

// sets lua up to use the same logging system as rust
pub fn set_lua_logging_hooks(lua: &Lua) {
    let logs = vec![(LogLevel::Error, "err"),
        (LogLevel::Warn, "warn"),
        (LogLevel::Info, "info"),
        (LogLevel::Debug, "debug"),
        (LogLevel::Trace, "trace")];

    let globals = lua.globals();

    // expose all logging functions to lua
    for (level, name) in logs {
        let log_fn = lua.create_function(move |_, msg: String| {
            log!(target: "lua", level, "{}", msg);
            Ok(())
        }).unwrap();

        globals.set(name, log_fn).unwrap();
    }
}

// helper function to read a file into a string
pub fn read_file_to_string(filename: &str) -> Result<String, Error> {
    let mut file = File::open(filename)
        .context(format!("failed to open file: '{}'", filename))?;

    let mut contents = String::new();
    file.read_to_string(&mut contents)
        .context(format!("failed to read file: '{}'", filename))?;

    Ok(contents)
}

pub fn parse_msg<'a>(re: &Regex, target: &str, msg: &'a str) -> Option<&'a str> {
    match target {
        // black list rizon network bots
        "py-ctcp" => {
            None
        },
        // direct messages
        x if !x.starts_with("#") => {
            Some(msg)
        },
        // capture all possible ways to address the bot
        _ => {
            re.captures(msg).map(|x| x.get(2).unwrap_or_else(|| x.get(1).unwrap()).as_str())
        }
    }
}
