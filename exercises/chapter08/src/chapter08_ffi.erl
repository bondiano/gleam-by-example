-module(chapter08_ffi).
-export([get_env/1, ensure_dir/1]).

get_env(Name) ->
    case os:getenv(binary_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, list_to_binary(Value)}
    end.

ensure_dir(Path) ->
    case filelib:ensure_dir(Path) of
        ok -> {ok, nil};
        {error, Reason} -> {error, Reason}
    end.
