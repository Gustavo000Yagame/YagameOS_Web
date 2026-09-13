global _start

section .data
    header_html:
        db "HTTP/1.1 200 OK", 13, 10, "Content-Type: text/html; charset=UTF-8", 13, 10, "Connection: close", 13, 10, 13, 10
    header_html_len equ $ - header_html

    header_wasm:
        db "HTTP/1.1 200 OK", 13, 10, "Content-Type: application/wasm", 13, 10, "Connection: close", 13, 10, 13, 10
    header_wasm_len equ $ - header_wasm

    header_download:
        db 'HTTP/1.1 200 OK', 13, 10, 'Content-Type: application/octet-stream', 13, 10, 'Content-Disposition: attachment; filename="yagameos.img"', 13, 10, 'Connection: close', 13, 10, 13, 10
    header_download_len equ $ - header_download

    header_404:
        db "HTTP/1.1 404 Not Found", 13, 10, "Content-Type: text/plain", 13, 10, "Connection: close", 13, 10, 13, 10, "404 - Not Found", 10
    header_404_len equ $ - header_404

    html_file db "index.html", 0
    wasm_file db "interface.wasm", 0
    img_file  db "yagameos.img", 0

    route_download db "GET /download", 0
    route_wasm     db "GET /interface.wasm", 0

    sockaddr:
        dw 2, 0x901F, 0, 0    ; AF_INET, Porta 8080
        
    optval dd 1               ; Habilita SO_REUSEADDR

section .bss
    request resb 4096

section .text

_start:
    mov rax, 41               ; sys_socket
    mov rdi, 2
    mov rsi, 1
    xor rdx, rdx
    syscall
    mov r12, rax

    ; Permite reusar a porta 8080 imediatamente sem esperar TIME_WAIT
    mov rax, 54               ; sys_setsockopt
    mov rdi, r12
    mov rsi, 1                ; SOL_SOCKET
    mov rdx, 2                ; SO_REUSEADDR
    lea r10, [rel optval]
    mov r8, 4
    syscall

    mov rax, 49               ; sys_bind
    mov rdi, r12
    lea rsi, [rel sockaddr]
    mov rdx, 16
    syscall

    mov rax, 50               ; sys_listen
    mov rdi, r12
    mov rsi, 10
    syscall

server_loop:
    mov rax, 43               ; sys_accept
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    syscall
    mov r13, rax

    mov rax, 0                ; sys_read
    mov rdi, r13
    lea rsi, [rel request]
    mov rdx, 4096
    syscall

    ; Checar /download
    lea rsi, [rel request]
    lea rdi, [rel route_download]
    mov rcx, 13
    repe cmpsb
    je serve_download

    ; Checar /interface.wasm
    lea rsi, [rel request]
    lea rdi, [rel route_wasm]
    mov rcx, 19
    repe cmpsb
    je serve_wasm

serve_index:
    mov rax, 2
    lea rdi, [rel html_file]
    mov rsi, 0
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl send_404
    mov r14, rax

    mov rax, 1
    mov rdi, r13
    lea rsi, [rel header_html]
    mov rdx, header_html_len
    syscall

    mov rax, 40
    mov rdi, r13
    mov rsi, r14
    xor rdx, rdx
    mov r10, 1048576
    syscall

    mov rax, 3
    mov rdi, r14
    syscall
    jmp close_client

serve_wasm:
    mov rax, 2
    lea rdi, [rel wasm_file]
    mov rsi, 0
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl send_404
    mov r14, rax

    mov rax, 1
    mov rdi, r13
    lea rsi, [rel header_wasm]
    mov rdx, header_wasm_len
    syscall

    mov rax, 40
    mov rdi, r13
    mov rsi, r14
    xor rdx, rdx
    mov r10, 1048576
    syscall

    mov rax, 3
    mov rdi, r14
    syscall
    jmp close_client

serve_download:
    mov rax, 2
    lea rdi, [rel img_file]
    mov rsi, 0
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl send_404
    mov r14, rax

    mov rax, 1
    mov rdi, r13
    lea rsi, [rel header_download]
    mov rdx, header_download_len
    syscall

    mov rax, 40
    mov rdi, r13
    mov rsi, r14
    xor rdx, rdx
    mov r10, 2147483647
    syscall

    mov rax, 3
    mov rdi, r14
    syscall
    jmp close_client

send_404:
    mov rax, 1
    mov rdi, r13
    lea rsi, [rel header_404]
    mov rdx, header_404_len
    syscall

close_client:
    mov rax, 3
    mov rdi, r13
    syscall
    jmp server_loop
