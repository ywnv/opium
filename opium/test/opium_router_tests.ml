module Router = Opium.Private.Router
open Router

let valid_route s =
  match Route.of_string s with
  | Error err -> print_endline ("[FAIL] invalid route " ^ err)
  | Ok _ -> print_endline "[PASS] valid route"
;;

let%expect_test "nil route" =
  valid_route "/";
  [%expect {| [PASS] valid route |}]
;;

let%expect_test "literal route" =
  valid_route "/foo/bar";
  [%expect {| [PASS] valid route |}]
;;

let%expect_test "named parameters valid" =
  valid_route "/foo/:param/:another";
  [%expect {| [PASS] valid route |}]
;;

let%expect_test "unnamed parameter valid" =
  valid_route "/foo/*";
  [%expect {| [PASS] valid route |}]
;;

let%expect_test "param followed by literal" =
  valid_route "/foo/*/bar/:param/bar";
  [%expect {| [PASS] valid route |}]
;;

let%expect_test "duplicate paramters" =
  valid_route "/foo/:bar/:bar/x";
  [%expect {| [FAIL] invalid route duplicate parameter "bar" |}]
;;

let test_match_url router url =
  match Router.match_url router url with
  | None -> print_endline "no match"
  | Some (_, p) -> Format.printf "matched with params: %a@." Params.pp p
;;

let%expect_test "dummy router matches nothing" =
  test_match_url empty "/foo/123";
  [%expect {|
    no match |}]
;;

let%expect_test "we can add & match literal routes" =
  let url = "/foo/bar" in
  let route = Route.of_string_exn url in
  let router = add empty route () in
  test_match_url router url;
  [%expect {|
    matched with params: { named = []  ; unnamed = [] } |}]
;;

let%expect_test "we can extract parameter after match" =
  let route = Route.of_string_exn "/foo/*/:bar" in
  let router = add empty route () in
  test_match_url router "/foo/100/baz";
  test_match_url router "/foo/100";
  test_match_url router "/foo/100/200/300";
  [%expect
    {|
    matched with params: { named = [(bar, 100)]  ; unnamed = [baz] }
    no match
    no match |}]
;;

let of_routes routes =
  List.fold_left
    (fun router (route, data) -> add router (Route.of_string_exn route) data)
    empty
    routes
;;

let of_routes' routes = routes |> List.map (fun r -> r, ()) |> of_routes

let%expect_test "ambiguity in routes" =
  of_routes' [ "/foo/baz"; "/foo/bar"; "/foo/*" ] |> ignore;
  [%expect.unreachable]
  [@@expect.uncaught_exn
    {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)

  (Failure "duplicate routes")
  Raised at file "stdlib.ml", line 29, characters 17-33
  Called from file "list.ml", line 121, characters 24-34
  Called from file "test/router_tests.ml", line 83, characters 2-49
  Called from file "collector/expect_test_collector.ml", line 244, characters 12-19 |}]
;;

let%expect_test "ambiguity in routes 2" =
  of_routes' [ "/foo/*/bar"; "/foo/bar/*" ] |> ignore;
  [%expect.unreachable]
  [@@expect.uncaught_exn
    {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)

  (Failure "duplicate routes")
  Raised at file "stdlib.ml", line 29, characters 17-33
  Called from file "list.ml", line 121, characters 24-34
  Called from file "test/router_tests.ml", line 99, characters 2-43
  Called from file "collector/expect_test_collector.ml", line 244, characters 12-19 |}]
;;

let%expect_test "nodes are matched correctly" =
  let router = of_routes [ "/foo/bar", "Wrong"; "/foo/baz", "Right" ] in
  let test url expected_value =
    match match_url router url with
    | Some (s, _) -> assert (s = expected_value)
    | None -> Format.printf "%a@." (Router.pp Format.pp_print_string) router
  in
  test "/foo/bar" "Wrong";
  test "/foo/baz" "Right";
  [%expect {| |}]
;;
