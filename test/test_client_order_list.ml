open Tea
open Tea.App
open Tea.Html
open Tea.Mouse

type msg =
  | Reset
  | DragStart of (int * position)
  | DragAt of position
  | DragEnd of position
  | Reverse
[@@bs.deriving {accessors}]


type drag =
  {
    itemIndex : int
  ; startY : int
  ; currentY : int
  }

type model =
  { data : string list
  ; drag : drag option
  }

let initialList =
  [ "Shawshank Redemption"
  ; "Godfather"
  ; "Dark Knight"
  ; "12 Angry Men"
  ; "Schindler’s List"
  ; "Pulp Fiction"
  ; "Lord of the Rings"
  ; "The Good, the Bad and the Ugly"
  ; "Fight Club"
  ; "The Empire Strikes Back"
  ]

let init () =
  ( {data = initialList ; drag = None}, Cmd.none )

let update model = function
  | Reset ->
    { model with data = initialList }, Cmd.none
  | Reverse -> { model with data = List.rev model.data }, Cmd.none
  | DragStart (itemIndex, pos) ->
    { model with drag = Some { itemIndex
                             ; startY = pos.y
                             ; currentY = pos.y
                             }
    }, Cmd.none
  | DragAt pos ->
    let drag =
      let drag : (drag -> drag [@bs]) = fun [@bs] { itemIndex ; startY } ->
        { itemIndex
        ; startY = startY
        ; currentY = pos.y
        } in
      Js.Option.map drag model.drag
    in
    { model with drag }, Cmd.none
  | DragEnd _pos ->
    let moveItem fromPos offset list =
      let offset = match offset with | 0 -> 0 | offset -> if offset > 0 then offset + 1 else offset -1 in
      list |> List.mapi (fun index item -> if index == fromPos then (index + offset, item) else (index, item) )
      |> List.sort (fun (index1, _item) (index2, _item) -> index1 - index2) |> List.map ( fun (_index, item) -> item)
    in
    (
      match model.drag with
      | Some { itemIndex; startY; currentY } ->
        { data =
            moveItem
              itemIndex
              ((currentY - startY
                + if currentY < startY then
                  -20
                else
                  20
               )
               / 50
              )
              model.data
        ; drag = None
        }
      | None -> { model with drag = None }
    ), Cmd.none


let subscriptions model =
  match model.drag with
  | None ->
    Sub.none

  | Some _ ->
    Sub.batch [ Mouse.moves dragAt; Mouse.ups dragEnd ]


let px number =
  (string_of_int number) ^ "px"

let onMouseDown mapper =
  onCB "mousedown" "" (fun ev ->
      Json.Decoder.decodeEvent (Json.Decoder.map mapper Mouse.position) ev
      |> Result.result_to_option
    )

let view model =
  let itemView model idx item =
    let moveStyle =
      match model.drag with
        Some { itemIndex; startY; currentY } ->
        if itemIndex == idx then
          [ ( "transform", "translateY( " ^ string_of_int (currentY - startY) ^ "px) translateZ(10px)" )
          ; ( "box-shadow", "0 3px 6px rgba(0,0,0,0.24)" )
          ; ( "willChange", "transform" )
          ]
        else
          [ ( "transform", "" )
          ; ( "box-shadow", "" )
          ; ( "willChange", "" )
          ]
      | None ->
        [ ( "transform", "" )
        ; ( "box-shadow", "" )
        ; ( "willChange", "" )
        ]
    in
    let makingWayStyle =
      match model.drag with
      | Some { itemIndex; startY; currentY } ->
        if (idx < itemIndex) && (currentY - startY) < (idx - itemIndex) * 50 + 20 then
          [ ( "transform", "translateY(50px)" )
          ; ( "transition", "transform 200ms ease-in-out" )
          ]
        else if (idx > itemIndex) && (currentY - startY) > (idx - itemIndex) * 50 - 20 then
          [ ( "transform", "translateY(-50px)" )
          ; ( "transition", "transform 200ms ease-in-out" )
          ]
        else if idx != itemIndex then
          [ ( "transform", "" )
          ; ( "transition", "transform 200ms ease-in-out" ) ]
        else
          [ ( "transform", "" )
          ; ( "transition", "" ) ]
      | None ->
        [ ( "transform", "" )
        ; ( "transition", "" ) ]
    in
    let styleList = List.concat [Drag_styles.listItem ; moveStyle ; makingWayStyle ; Drag_styles.unselectable] in
    li
      [ styles styleList ; onMouseDown (fun x -> dragStart (idx, x))]
      [ div [ styles (List.concat [Drag_styles.itemText ; Drag_styles.unselectable]) ] [ text item ]
      ]
  in
  let toggleButton _model =
    button [ onClick Reset ] [ text {js|reset|js} ]
  in
  let dragBody =
    div
      [ styles Drag_styles.pageContainer ]
      [ div
          [ styles Drag_styles.listHeader ]
          [ h3
              [ styles Drag_styles.headerTitle ]
              [ text "Sortable favorite movies" ]
          ; toggleButton model ; button [onClick Reverse] [text {js|Reverse|js}] ]
      ; ul
          [ styles Drag_styles.listContainer ]
          (List.mapi (itemView model) model.data)
      ]
  in
  dragBody

let main =
  standardProgram {
    init;
    update;
    view;
    subscriptions;
  }