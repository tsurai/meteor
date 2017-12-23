// boilerplate for error_chain
error_chain! {
    foreign_links {
        Io(::std::io::Error);
        Log(::log::SetLoggerError);
        Irc(::irc::error::Error);
        Lua(::rlua::Error);
    }
}

