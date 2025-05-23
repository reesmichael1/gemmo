open Base

let load_uri net uri =
  let open Or_error.Let_syntax in
  let%bind host =
    Or_error.of_option
      ~error:(Error.create_s [%message "no hostname given in URI"])
    @@ Uri.host uri
  in
  let%bind hostname =
    Result.map_error ~f:(fun _ ->
        Error.create_s [%message "could not extract domain name from hostname"])
    @@ Domain_name.of_string host
  in
  try
    Eio.Net.with_tcp_connect ~host ~service:"1965" net @@ fun conn ->
    let client =
      match
        Tls.Config.client ~authenticator:(fun ?ip:_ ~host:_ _ -> Ok None) ()
      with
      | Ok c -> c
      | Error _ -> failwith "could not establish TLS connection"
    in

    let flow =
      Tls_eio.client_of_flow ~host:(Domain_name.host_exn hostname) client conn
    in

    Eio.Buf_write.with_flow flow @@ fun to_server ->
    let query = Printf.sprintf "%s\r\n" @@ Uri.to_string uri in
    Eio.Buf_write.string to_server query;
    Ok (Eio.Flow.read_all flow)
  with _ -> Or_error.error_s [%message "could not open TCP connection"]
