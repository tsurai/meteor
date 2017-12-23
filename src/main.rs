#![recursion_limit = "1024"]

#[macro_use]
extern crate error_chain;
#[macro_use]
extern crate log;
extern crate fern;
extern crate clap;
extern crate regex;
extern crate irc;
extern crate rlua;
extern crate chrono;

mod errors;
mod util;

use clap::{Arg, App, ArgMatches};
use clap::AppSettings::*;
use errors::*;

use std::default::Default;
use regex::Regex;
use irc::client::prelude::*;
use rlua::Lua;

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
        .get_matches()
}

fn init_logger(logfile: &str, verbosity: u64) -> Result<()> {
    fern::Dispatch::new()
        .format(|out, message, record| {
            out.finish(format_args!("[{}] {}", record.level(), message))
        })
        .level(match verbosity {
            1 => log::LogLevelFilter::Debug,
            x if x > 1 => log::LogLevelFilter::Trace,
            _ => log::LogLevelFilter::Info
        })
        .chain(
            fern::Dispatch::new().chain(::std::io::stdout()))
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
                               .chain_err(|| "failed to open log file")?)))
        .apply()
        .map_err(|e| e.into())
}

fn start_bot() -> Result<()> {
    let server = IrcServer::new("/home/tsurai/.local/meteor/config.toml")
        .chain_err(|| "failed to create IRC server object")?;

    let bot_nick = server.current_nickname().clone();
    let re = Regex::new(&format!("{}[,:]?\\s?(.*)", bot_nick)).unwrap();

    // creates a Lua context
    let lua = Lua::new();

    let plugin_host = util::read_file_to_string("lua/plugin_host.lua")?;
    let host = lua.exec::<rlua::Function>(plugin_host.as_str(), Some("PluginHost"))
        .chain_err(|| "failed to initialize PluginHost")?;
    let process = host.call::<(&str), rlua::Function>(("./lua/plugins"))?;

    server.identify()?;

    server.for_each_incoming(|message| {
        let nickname = message.source_nickname();
        let target = message.response_target();

        match message.command {
            Command::PRIVMSG(_, ref msg) => {
                let nickname = nickname.unwrap();
                let target = target.unwrap();

                if let Some(cmd) = util::parse_msg(&re, target, msg) {
                    let rep = process.call::<(&str,&str,&str), rlua::String>((nickname, target, cmd));
                    if let Ok(rep) = rep {
                        server.send_privmsg(target, rep.to_str().unwrap()).unwrap();
                    }
                }
            },
            _ => { }
        }
    })?;

    Ok(())
}

fn run() -> Result<()> {
    let matches = process_cli();
    let verbosity = matches.occurrences_of("verbose");

    init_logger("/home/tsurai/.local/meteor/meteor.log", verbosity)
        .chain_err(|| "failed to setup logging system")?;

   start_bot()
}

fn main() {
    // error_chain boilerplate
    if let Err(ref e) = run() {
        error!("{}", e);

        for e in e.iter().skip(1) {
            error!("caused by: {}", e);
        }

        if let Some(backtrace) = e.backtrace() {
            error!("backtrace: {:?}", backtrace);
        }

        ::std::process::exit(1);
    }
}
