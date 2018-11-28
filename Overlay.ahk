; GDIP Image Viewer
; Uncomment if Gdip is not in your standard library
#include Gdip.ahk
; http://ahkscript.org/boards/viewtopic.php?f=6&t=6517

; /*************************************
; HOTKEYS:
; *************************************/
; F1: load new image
; esc: exit
; lbutton: drag image
; space: zoom large image to fit screen
; rbutton: reload image
; up/wheelup: zoom up
; down/wheeldown: zoom down
; left/xbutton1: rotate left
; right/xbutton2: rotate right
; ctrl-t: toggle window visibility
; /*************************************
; CONFIG:
; *************************************/
; set zoom step in px (absolute) OR  fraction (relative, 0.1 = 10%)
step := 0.1
; set angle step in degrees when rotating
angle := 90 
; resample @ half res (faster for large images)
lres := false
; default image file to load
file := "circle.png"
; /*************************************
; END CONFIG
; *************************************/

global main :=, x:=, y := ""

; gdip init
if !pToken := Gdip_Startup() {
    msgbox, % 0x0 | 0x30, Error, Gdiplus failed to start.
    exitapp
}

go:
if main
    Gui 1: Hide
; select file
if !file
    FileSelectFile file, 35,, Load image:
if errorlevel
    exitapp
Gui 1: -Caption +E0x80000 +E0x40000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs hwndmain
Gui 1: Show
; load image
if !pBitmap := Gdip_CreateBitmapFromFile(file) {
    msgbox % 0x0 | 0x30, Error, Could not load the file.
    exitapp
}
Gdip_GetImageDimensions(pBitmap, owidth, oheight)
if lres
    pBitmap := scale(pBitmap, owidth, oheight)
zoomtofit(zwidth, zheight, owidth, oheight)
x := (a_screenwidth - zwidth) // 2, y := (a_screenheight - zheight) // 2, tangle := 0
draw(pBitmap, zwidth, zheight)
; monitor input
OnMessage(0x201, "WM_LBUTTONDOWN")
onexit _exit
return

; draw/redraw window
draw(pBitmap, zwidth, zheight) {
    ; recenter
    static pwidth, pheight
    if pwidth
        x += round((pwidth - zwidth) / 2), y += round((pheight - zheight) / 2)
    pwidth := zwidth, pheight := zheight

    ; draw
    hdc     := CreateCompatibleDC()
    hbm     := CreateDIBSection(zwidth, zheight)
    obm     := SelectObject(hdc, hbm)
    G           := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetInterpolationMode(G, 7)
    Gdip_DrawImage(G, pBitmap, 0, 0, zwidth, zheight)
    UpdateLayeredWindow(main, hdc, x, y, zwidth, zheight)

    ; cleanup
    SelectObject(hdc, obm)
    DeleteObject(hbm)
    DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
}

; Gdip_GetRotatedDimensions using ceil() not floor() adds 1 px to w/h every call, this is annoying
GetRotatedDimensions(Width, Height, Angle, ByRef RWidth, ByRef RHeight) {
    pi := 3.14159, TAngle := Angle*(pi/180)
    if !(Width && Height)
        return -1
    RWidth := floor(Abs(Width*Cos(TAngle))+Abs(Height*Sin(TAngle)))
    RHeight := floor(Abs(Width*Sin(TAngle))+Abs(Height*Cos(Tangle)))
}

; rotate image
rotate(pBitmap, angle, zwidth, zheight) {
    if (angle = 0) || (angle = 360) {
        draw(pBitmap, zwidth, zheight)
        return
    }

    ; rotate dimensions
    GetRotatedDimensions(zwidth, zheight, angle, rwidth, rheight)
    Gdip_GetRotatedTranslation(zwidth, zheight, angle, xTranslation, yTranslation)

    ; redraw
    rBitmap := Gdip_CreateBitmap(rwidth, rheight)
    rG := Gdip_GraphicsFromImage(rBitmap)
    Gdip_SetInterpolationMode(rG, 7)
    Gdip_TranslateWorldTransform(rG, xTranslation, yTranslation)
    Gdip_RotateWorldTransform(rG, angle)
    Gdip_DrawImage(rG, pBitmap, 0, 0, zwidth, zheight)
    draw(rBitmap, rwidth, rheight)

    ; cleanup
    Gdip_ResetWorldTransform(rG)
    Gdip_DeleteGraphics(rG)
    Gdip_DisposeImage(rBitmap)
}

; rescale image
scale(pBitmap, width, height) {
    ; halve res
    dpix := Gdip_GetImageHorizontalResolution(pBitmap)
    dpiy := Gdip_GetImageVerticalResolution(pBitmap)
    dpix := round(dpix / 2), dpiy := round(dpiy / 2)
    nBitmap := Gdip_CreateBitmap(width, height)
    Gdip_BitmapSetResolution(nBitmap, dpix, dpiy)

    ; redraw
    nG := Gdip_GraphicsFromImage(nBitmap)
    Gdip_SetInterpolationMode(nG, 7)
    Gdip_DrawImage(nG, pBitmap, 0, 0, width, height)

    ; cleanup
    Gdip_DeleteGraphics(nG)
    Gdip_DisposeImage(pBitmap)
    return nBitmap
}

; lbutton drag window, update position
WM_LBUTTONDOWN() {
    If (A_Gui = 1)
        PostMessage 0xA1, 2
    keywait lbutton
    wingetpos x, y,,, ahk_id %main%
}

; resize
zoom(byref zwidth, byref zheight, step) {
    ; preserve AR: (height / width) x zwidth = zheight
    width := zwidth, height := zheight
    if (abs(step) < 1)
        step := round(zwidth * step)
    zwidth += ((zwidth + step) >= 20) ? step : 0
    zheight := (height / width) * zwidth
}

; size large images to fit screen
zoomtofit(byref zwidth, byref zheight, width, height) {
    if (width > a_screenwidth) {
        zwidth := a_screenwidth
        zheight := (height / width) * zwidth
    }
    if (zheight > a_screenheight) {
        zheight := a_screenheight
        zwidth := (width / height) * zheight
    }
    else
        zwidth := width, zheight := height
}

_exit:
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)
    exitapp
Return

; keybinds
^+s::gui % winexist("ahk_id " main) ? "1: hide" : "1: show"
#if winexist("ahk_id " main)
f1::
    Gdip_DisposeImage(pBitmap)
    gosub go
return
#if winactive("ahk_id " main)
esc::exitapp
space::
    zoomtofit(zwidth, zheight, owidth, oheight)
    rotate(pBitmap, tangle, zwidth, zheight)
return
rbutton up::
    zwidth := owidth, zheight := oheight, tangle := 0
    draw(pBitmap, zwidth, zheight)
return
up::
wheelup::
    zoom(zwidth, zheight, step)
    rotate(pBitmap, tangle, zwidth, zheight)
return
down::
wheeldown::
    zoom(zwidth, zheight, -step)
    rotate(pBitmap, tangle, zwidth, zheight)
return
left::
xbutton1::
    tangle -= abs(tangle - angle) <= 360 ? angle : -(360 - angle)
    rotate(pBitmap, tangle, zwidth, zheight)
return
right::
xbutton2::
    tangle += abs(tangle + angle) <= 360 ? angle : -(360 - angle)
    rotate(pBitmap, tangle, zwidth, zheight)
return