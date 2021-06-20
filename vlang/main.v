import os
import rand
import time


const (
  ram_size = 0x1000
  stack_size = 0x10
  font_address = 0x50 // it’s become popular to put fonts at 050–09F
  program_start_address = 0x200
  max_sprite_height = 0xF
  interval = time.second / 700
)

struct Stack {
mut:
  array [stack_size]u16
  size  byte
}

struct Chip8 {
  modern_behavior bool [required]
mut:
  video           &Video = 0
  ram             [ram_size]byte
  stack           Stack
  pc              u16 = program_start_address
  i               u16
  v               [0x10]byte
  delay_timer     byte
  sound_timer     byte
}

fn (mut stack Stack) push(e u16) {
  if stack.size == stack_size {
    panic("Stack overflow")
  }

  stack.array[stack.size] = e
  stack.size += 1
}

fn (mut stack Stack) pop() u16 {
  if stack.size == 0 {
    panic("Stack underflow")
  }

  stack.size -= 1
  return stack.array[stack.size]
}

fn (mut chip8 Chip8) load_font() {
  font := [
    byte(0xF0), 0x90,  0x90,  0x90,  0xF0, // 0
         0x20,  0x60,  0x20,  0x20,  0x70, // 1
         0xF0,  0x10,  0xF0,  0x80,  0xF0, // 2
         0xF0,  0x10,  0xF0,  0x10,  0xF0, // 3
         0x90,  0x90,  0xF0,  0x10,  0x10, // 4
         0xF0,  0x80,  0xF0,  0x10,  0xF0, // 5
         0xF0,  0x80,  0xF0,  0x90,  0xF0, // 6
         0xF0,  0x10,  0x20,  0x40,  0x40, // 7
         0xF0,  0x90,  0xF0,  0x90,  0xF0, // 8
         0xF0,  0x90,  0xF0,  0x10,  0xF0, // 9
         0xF0,  0x90,  0xF0,  0x90,  0x90, // A
         0xE0,  0x90,  0xE0,  0x90,  0xE0, // B
         0xF0,  0x80,  0x80,  0x80,  0xF0, // C
         0xE0,  0x90,  0x90,  0x90,  0xE0, // D
         0xF0,  0x80,  0xF0,  0x80,  0xF0, // E
         0xF0,  0x80,  0xF0,  0x80,  0x80, // F
  ]!
  offset := font_address
  mut i := 0
  for b in font {
    chip8.ram[i + offset] = b
    i += 1
  }
}

fn (mut chip8 Chip8) load_program(filename string) {
  mut file := os.open(filename) or {
    eprintln(err.msg)
    exit(-1)
  }
  defer {
    file.close()
  }
  buffer_size := 64
  mut buf := []byte{cap: buffer_size}
  mut pos := u64(0)
  buf = file.read_bytes_at(buffer_size, pos)
  for buf.len > 0 {
    for b in buf {
      chip8.ram[program_start_address + pos] = b
      pos += 1
    }
    buf = file.read_bytes_at(buffer_size, pos)
  }
}

fn (mut chip8 Chip8) run_timers() {
  for {
    if chip8.delay_timer > 0 {
      chip8.delay_timer -= 1
    }
    if chip8.sound_timer > 0 {
      chip8.sound_timer -= 1
    }
    time.sleep(time.second / 60)
  }
}

fn (chip8 Chip8) fetch() (byte, byte, byte, byte, byte, u16) {
  nibble := chip8.ram[chip8.pc] >> 4
  x      := chip8.ram[chip8.pc] & 0xF
  y      := chip8.ram[chip8.pc + 1] >> 4
  n      := chip8.ram[chip8.pc + 1] & 0xF
  nn     := chip8.ram[chip8.pc + 1]
  nnn    := u16(x << 8) + nn
  return nibble, x, y, n, nn, nnn
}

fn handle_invalid_op(nibble byte, nnn u16) {
  eprintln("Invalid instruction 0x${nibble:x}${nnn:03x}")
  exit(-1)
}

fn (mut chip8 Chip8) clear_screen() {
  chip8.video.clear_screen()
}

fn (mut chip8 Chip8) jump(nnn u16) {
  chip8.pc = nnn
}

fn (mut chip8 Chip8) set(x byte, nn byte) {
  chip8.v[x] = nn
}

fn (mut chip8 Chip8) add_number(x byte, nn byte) {
  chip8.v[x] += nn
}

fn (mut chip8 Chip8) set_index(nnn u16) {
  chip8.i = nnn
}

fn (mut chip8 Chip8) display(x byte, y byte, n byte) {
  coordinate_x := chip8.v[x]
  coordinate_y := chip8.v[y]
  sprite := chip8.ram[chip8.i..chip8.i + n]
  off := chip8.video.draw_sprite(coordinate_x, coordinate_y, sprite)
  chip8.set(0xF, byte(off))
}

fn (mut chip8 Chip8) return_subroutine() {
  chip8.pc = chip8.stack.pop()
}

fn (mut chip8 Chip8) call_subroutine(nnn u16) {
  chip8.stack.push(chip8.pc)
  chip8.jump(nnn)
}

fn (mut chip8 Chip8) skip3(x byte, nn byte) {
  if chip8.v[x] == nn {
    chip8.pc += 2
  }
}

fn (mut chip8 Chip8) skip4(x byte, nn byte) {
  if chip8.v[x] != nn {
    chip8.pc += 2
  }
}

fn (mut chip8 Chip8) skip5(x byte, y byte) {
  if chip8.v[x] == chip8.v[y] {
    chip8.pc += 2
  }
}

fn (mut chip8 Chip8) skip9(x byte, y byte) {
  if chip8.v[x] != chip8.v[y] {
    chip8.pc += 2
  }
}

fn (mut chip8 Chip8) copy(x byte, y byte) {
  chip8.v[x] = chip8.v[y]
}

fn (mut chip8 Chip8) bitwise_or(x byte, y byte) {
  chip8.v[x] |= chip8.v[y]
}

fn (mut chip8 Chip8) bitwise_and(x byte, y byte) {
  chip8.v[x] &= chip8.v[y]
}

fn (mut chip8 Chip8) bitwise_xor(x byte, y byte) {
  chip8.v[x] ^= chip8.v[y]
}

fn (mut chip8 Chip8) add_record(x byte, y byte) {
  chip8.v[x] += chip8.v[y]
  chip8.v[0xF] = if chip8.v[x] < chip8.v[y] { byte(1) } else { byte(0) }
}

fn (mut chip8 Chip8) substract_x_y(x byte, y byte) {
  chip8.v[0xF] = if chip8.v[x] > chip8.v[y] { byte(1) } else { byte(0) }
  chip8.v[x] -= chip8.v[y]
}

fn (mut chip8 Chip8) substract_y_x(x byte, y byte) {
  chip8.v[0xF] = if chip8.v[y] > chip8.v[x] { byte(1) } else { byte(0) }
  chip8.v[x] = chip8.v[y] - chip8.v[x]
}

fn (mut chip8 Chip8) shift(x byte, y byte, right bool) {
  if !chip8.modern_behavior {
    chip8.v[x] = chip8.v[y]
  }
  if right {
    chip8.v[0xF] = chip8.v[x] & 0x1
    chip8.v[x] >>= 1
  } else {
    chip8.v[0xF] = chip8.v[x] & 0x80
    chip8.v[x] <<= 1
  }
}

fn (mut chip8 Chip8) offset_jump(x byte, nnn u16) {
  chip8.pc = nnn
  chip8.pc += if chip8.modern_behavior { chip8.v[x] } else { chip8.v[0] }
}

fn (mut chip8 Chip8) random(x byte, nn byte) {
  chip8.v[x] = rand.byte() & nn
}

fn (mut chip8 Chip8) skip_if_key(x byte, is_pressed bool) {
  if chip8.video.keyboard[chip8.v[x]] == is_pressed {
    chip8.pc += 2
  }
}

fn (mut chip8 Chip8) copy_delay_to_vx(x byte) {
  chip8.v[x] = chip8.delay_timer
}

fn (mut chip8 Chip8) get_key(x byte) {
  mut i := byte(0)
  for key in chip8.video.keyboard {
    if key {
      chip8.v[x] = i
    }
    i += 1
  }
}

fn (mut chip8 Chip8) copy_vx_to_delay(x byte) {
  chip8.delay_timer = chip8.v[x]
}

fn (mut chip8 Chip8) copy_vx_to_sound(x byte) {
  chip8.sound_timer = chip8.v[x]
}

fn (mut chip8 Chip8) add_vx_to_i(x byte) {
  chip8.i += chip8.v[x]
  // The following block does not represent the behaviour of all CHIP-8 interpreters.
  // Some games rely on this behaviour being present, while no games are known to rely on this
  // behaviour *not* being present, therefore I include it.
  if chip8.i >= ram_size {
    chip8.v[0xF] = byte(1)
  }
}

fn (mut chip8 Chip8) get_character(x byte) {
  character := chip8.v[x] & 0xF
  chip8.i = font_address + 5 * character
}

fn (mut chip8 Chip8) convert_to_decimal(x byte) {
  chip8.ram[chip8.i + 0] = chip8.v[x] / byte(100)
  chip8.ram[chip8.i + 1] = (chip8.v[x] / byte(10)) % 10
  chip8.ram[chip8.i + 2] = chip8.v[x] % 10
}

fn (mut chip8 Chip8) store_v(x byte) {
  for i in 0..x + 1 {
    chip8.ram[chip8.i + i] = chip8.v[i]
  }
  if !chip8.modern_behavior {
    chip8.i += x + 1
  }
}

fn (mut chip8 Chip8) load_v(x byte) {
  for i in 0..x + 1 {
    chip8.v[i] = chip8.ram[chip8.i + i]
  }
  if !chip8.modern_behavior {
    chip8.i += x + 1
  }
}

fn (chip8 Chip8) core_dump() {
    nibble, _, _, _, _, nnn := chip8.fetch()
    println(
      "0x${nibble:x}${nnn:03x} | ${chip8.i:04x} | " +
      "${chip8.v[0x0]:02x} ${chip8.v[0x1]:02x} ${chip8.v[0x2]:02x} ${chip8.v[0x3]:02x} " +
      "${chip8.v[0x4]:02x} ${chip8.v[0x5]:02x} ${chip8.v[0x6]:02x} ${chip8.v[0x7]:02x} " +
      "${chip8.v[0x8]:02x} ${chip8.v[0x9]:02x} ${chip8.v[0xA]:02x} ${chip8.v[0xB]:02x} " +
      "${chip8.v[0xC]:02x} ${chip8.v[0xD]:02x} ${chip8.v[0xE]:02x} ${chip8.v[0xF]:02x}"
    )
}

fn (mut chip8 Chip8) run() {
  for {
    nibble, x, y, n, nn, nnn := chip8.fetch()
    chip8.pc += 2
    match nibble {
      0x0 {
        match nnn {
          0x0E0 { chip8.clear_screen() }
          0x0EE { chip8.return_subroutine() }
          else { handle_invalid_op(x, nnn) }
        }
      }
      0x1 { chip8.jump(nnn) }
      0x2 { chip8.call_subroutine(nnn) }
      0x3 { chip8.skip3(x, nn) }
      0x4 { chip8.skip4(x, nn) }
      0x5 { chip8.skip5(x, y) }
      0x6 { chip8.set(x, nn) }
      0x7 { chip8.add_number(x, nn) }
      0x8 {
        match n {
          0x0 { chip8.copy(x, y) }
          0x1 { chip8.bitwise_or(x, y) }
          0x2 { chip8.bitwise_and(x, y) }
          0x3 { chip8.bitwise_xor(x, y) }
          0x4 { chip8.add_record(x, y) }
          0x5 { chip8.substract_x_y(x, y) }
          0x6 { chip8.shift(x, y, true) }
          0x7 { chip8.substract_y_x(x, y) }
          0xE { chip8.shift(x, y, false) }
          else { handle_invalid_op(x, nnn) }
        }
      }
      0x9 { chip8.skip9(x, y) }
      0xA { chip8.set_index(nnn) }
      0xB { chip8.offset_jump(x, nnn) }
      0xC { chip8.random(x, nn) }
      0xD { chip8.display(x, y, n) }
      0xE {
        match nn {
          0x9E { chip8.skip_if_key(x, true) }
          0xA1 { chip8.skip_if_key(x, false) }
          else { handle_invalid_op(x, nnn) }
        }
      }
      0xF {
        match nn {
          0x07 { chip8.copy_delay_to_vx(x) }
          0x0A { chip8.get_key(x) }
          0x15 { chip8.copy_vx_to_delay(x) }
          0x18 { chip8.copy_vx_to_sound(x) }
          0x1E { chip8.add_vx_to_i(x) }
          0x29 { chip8.get_character(x) }
          0x33 { chip8.convert_to_decimal(x) }
          0x55 { chip8.store_v(x) }
          0x65 { chip8.load_v(x) }
          else { handle_invalid_op(x, nnn) }
        }
      }
      else { handle_invalid_op(x, nnn) }
    }
    time.sleep(interval)
  }
}

fn main() {
  if os.args.len < 2 {
    eprintln("Must provide a path to a program as the first argument")
    exit(-1)
  }
  old_behaviour := os.args.len > 2 && os.args[2] == '--old-behaviour'
  path_parts := os.args[1].split('/')
  filename := path_parts[path_parts.len - 1]
  mut chip8 := &Chip8{
    modern_behavior: !old_behaviour
    video: get_video(filename)
  }
  chip8.load_font()
  chip8.load_program(os.args[1])
  go chip8.run_timers()
  go chip8.video.run()
  chip8.run()
}
