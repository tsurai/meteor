use std::fs::File;
use std::io::Read;
use regex::Regex;
use errors::*;

pub fn read_file_to_string(filename: &str) -> Result<String> {
    let mut file = File::open(filename)
        .chain_err(|| format!("failed to open file: '{}'", filename))?;

    let mut contents = String::new();
    file.read_to_string(&mut contents)
        .chain_err(|| format!("failed to read file: '{}'", filename))?;

    Ok(contents)
}

pub fn parse_msg<'a>(re: &Regex, target: &str, msg: &'a str) -> Option<&'a str> {
    match target {
        // black list rizon network bots
        "py-ctcp" => {
            None
        },
        x if !x.starts_with("#") => {
            Some(msg)
        },
        _ => {
            re.captures(msg).map(|x| x.get(1).unwrap().as_str())
        }
    }
}
