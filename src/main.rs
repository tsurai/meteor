#[macro_use]
extern crate log;
extern crate failure;
extern crate fern;
extern crate clap;
extern crate regex;
extern crate irc;
extern crate rlua;
extern crate chrono;

mod util;

use clap::{Arg, App, ArgMatches};
use clap::AppSettings::*;
use regex::Regex;
use irc::client::prelude::*;
use rlua::Lua;
use failure::*;

// process cli arguments with clap
fn process_cli<'a>() -> ArgMatches<'a> {
    App::new("meteor")
        .version("0.1")
        .author("Cristian Kubis <cristian.kubis@tsunix.de>")
        .about("Experimental irc bot")
        .setting(DeriveDisplayOrder)
        .arg(Arg::with_name("verbose")
             .short("v")
             .long("verbose")
             .multiple(true)
             .help("increrases the logging verbosity each use for up to 2 times"))
        .arg(Arg::with_name("config")
             .short("c")
             .long("config")
             .value_name("FILE")
             .takes_value(true)
             .help("absolute path to the config file. Default path is /var/lib/meteor/config.toml"))
        .get_matches()
}

// initiates the logging system for both rust and lua
fn init_logger(logfile: String, verbosity: u64) -> Result<(), Error> {
    fern::Dispatch::new()
        // prefix logging messages from lua
        .format(|out, message, record| {
            let target = if record.target() == "lua" {
                "[lua]"
            } else {
                ""
            };
            out.finish(format_args!("[{}]{} {}", record.level(), target, message))
        })
        .level(match verbosity {
            1 => log::LogLevelFilter::Debug,
            x if x > 1 => log::LogLevelFilter::Trace,
            _ => log::LogLevelFilter::Info
        })
        // output to stdout
        .chain(
            fern::Dispatch::new().chain(::std::io::stdout()))
        // output error messages additionally to a log file
        .chain(
            fern::Dispatch::new()
                .level(log::LogLevelFilter::Error)
                .chain(
                    fern::Dispatch::new()
                        .format(|out, message, _| {
                            out.finish(format_args!("{} {}",
                                chrono::Local::now().format("%d-%m-%Y %H:%M:%S"),
                                message))
                        })
                        .chain(fern::log_file(logfile)
                               .context("failed to open log file")?)))
        .apply()
        .map_err(|e| e.into())
}

fn start_bot(config: Config) -> Result<(), Error> {
    // create a new IrcClient instance from config file
    let client = IrcClient::from_config(config)
        .context("failed to create IRC server object")?;

    // get the current bot nickname
    let bot_nick = client.current_nickname().clone();

    // read the nick auth password from config
    let password: String = client.config().options
        .as_ref()
        .ok_or(format_err!("failed to get nick password. Missing additional options field in config"))?
        .get("nick_password")
        .ok_or(format_err!("failed to get nick password. Not found in options map"))?
        .clone();

    // precompile regular expression for later use in msg processing
    let re = Regex::new(&format!("(?:{}[,:]?\\s?(.*))|(!.*)", bot_nick))
        .map_err(|e| format_err!("failed to compile regex: {}", e))?;

    // creates a Lua context
    let lua = Lua::new();
    util::set_lua_logging_hooks(&lua);

    // load the lua plugin host source code
    let plugin_host = util::read_file_to_string("lua/plugin_host.lua")?;

    // execute the plugin host lua script returning the initialization function
    let host = lua.exec::<rlua::Function>(plugin_host.as_str(), Some("PluginHost"))
        .context("failed to initialize PluginHost")?;
    // call the initialization function with the path to the lua plugins
    let process = host.call::<(&str), rlua::Function>("lua/plugins")?;

    // identify with the IRC server using the nick supplied in the config
    client.identify()
        .context("failed to identify with the IRC server")?;

    // loop over incoming messages
    client.for_each_incoming(|message| {
        let nickname = message.source_nickname();
        let target = message.response_target();

        match message.command {
            // match NOTICE messages coming from NickServ
            Command::NOTICE(_, ref msg) => {
                // once connected NickServ will ask for the nickname password
                if nickname == Some("NickServ") && msg.contains("IDENTIFY") {
                    client.send(Command::PRIVMSG("NickServ".to_string(), format!("IDENTIFY {}", password))).ok();
                }
            }

            Command::PRIVMSG(_, ref msg) => {
                let nickname = nickname.unwrap();
                let target = target.unwrap();

                // parse the message to check if it is directed at the bot
                if let Some(cmd) = util::parse_msg(&re, target, msg) {
                    // forward the message to the lua plugin system
                    let rep = process.call::<(&str,&str,&str), rlua::String>((nickname, target, cmd));
                    if let Ok(rep) = rep {
                        // send the reply from the plugin
                        client.send_privmsg(target, rep.to_str().unwrap()).unwrap();
                    }
                }
            },
            _ => { }
        }
    })?;

    Ok(())
}

fn run() -> Result<(), Error> {
    let matches = process_cli();
    let verbosity = matches.occurrences_of("verbose");
    let config_path = matches.value_of("config")
        .unwrap_or("/usr/lib/meteor/config.toml");

    let config = Config::load(config_path)
        .context("failed to load config file")?;

    // read the logfile path from config or use default
    let logfile_path = match config.options {
        Some(ref options) => {
            options.get("logfile_path").map(|x| x.clone())
        },
        None => {
            None
        }
    }
    .unwrap_or("/var/log/meteor/meteor.log".to_string());

    init_logger(logfile_path, verbosity)
        .context("failed to setup logging system")?;

    // start the bot and loop over incoming messages
    start_bot(config)
}

fn main() {
    // failure crate boilerplate
    if let Err(e) = run() {
        use std::io::Write;
        let mut stderr = std::io::stderr();
        let got_logger = log_enabled!(log::LogLevel::Error);

        let mut fail: &Fail = e.cause();
        if got_logger {
            error!("{}", fail);
        } else {
            writeln!(&mut stderr, "{}", fail).ok();
        }

        while let Some(cause) = fail.cause() {
            if got_logger {
                error!("caused by: {}", cause);
            } else {
                writeln!(&mut stderr, "caused by: {}", cause).ok();
            }

            if let Some(bt) = cause.backtrace() {
                error!("backtrace: {}", bt)
            }
            fail = cause;
        }

        stderr.flush().ok();
        ::std::process::exit(1);
    }
}
