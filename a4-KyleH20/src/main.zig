const std = @import("std");
const testing = std.testing;
const alloc = @import("./alloc.zig");

var alloc_inst = alloc.AllocTree(){};
const myalloc = alloc_inst.allocator();

test "Chunk.getSize()" {
    var chunk = alloc.Chunk{
        .size = 101,
    };
    try testing.expectEqual(@as(usize, 100), chunk.getSize());
    chunk.size = 64;
    try testing.expectEqual(@as(usize, 64), chunk.getSize());
    chunk.size = 65;
    try testing.expectEqual(@as(usize, 64), chunk.getSize());
}

test "Chunk.isFree()" {
    var chunk = alloc.Chunk{
        .size = 101,
    };
    try testing.expectEqual(false, chunk.isFree());
    chunk.size = 64;
    try testing.expectEqual(true, chunk.isFree());
    chunk.size = 65;
    try testing.expectEqual(false, chunk.isFree());
}

test "Chunk.fromBytes()" {
    var chunk: alloc.Chunk = alloc.Chunk{
        .size = 101,
    };
    var bytes = std.mem.toBytes(chunk)[0..];
    try testing.expectEqual(chunk, alloc.Chunk.fromBytes(bytes).*);
}

test "Chunk.getPayload()" {
    var page: []u8 = try std.testing.allocator.alloc(u8, alloc.HEADER * 3);
    defer std.testing.allocator.free(page);
    alloc.Chunk.writeChunk(page, 8);

    var i: usize = 8;
    while (i < 16) : (i += 1) {
        page[i] = 0xCD;
    }

    var chunk = alloc.Chunk.fromBytes(page);
    try testing.expectEqual(@as(usize, 8), chunk.getSize());
    try testing.expectEqualSlices(u8, ([_]u8{0xCD} ** 8)[0..8], chunk.getPayload());
}

test "write Chunk to page" {
    var page: []u8 = try std.testing.allocator.alloc(u8, alloc.HEADER * 3);
    defer std.testing.allocator.free(page);
    alloc.Chunk.writeChunk(page, 6);
    try testing.expectEqual(@as(usize, 6), alloc.Chunk.fromBytes(page).getSize());
}

test "get Chunk header" {
    var slice: []u8 = try std.testing.allocator.alloc(u8, alloc.HEADER * 3);
    defer std.testing.allocator.free(slice);
    alloc.Chunk.writeChunk(slice, 6);
    try testing.expectEqual(@as(usize, 6), alloc.Chunk.getHeader(slice[alloc.HEADER..(alloc.HEADER + 6)]).getSize());
}

test "get Chunk footer and is free" {
    var slice: []u8 = try std.testing.allocator.alloc(u8, alloc.HEADER * 3);
    defer std.testing.allocator.free(slice);
    alloc.Chunk.writeChunk(slice, 8);
    try testing.expectEqual(true, alloc.Chunk.getFooter(slice[alloc.HEADER..(alloc.HEADER + 8)]).isFree());
}

test "Chunk.setFreeFlag()" {
    var page: []u8 = try std.testing.allocator.alloc(u8, alloc.HEADER * 3);
    defer std.testing.allocator.free(page);
    alloc.Chunk.writeChunk(page, 8);

    var i: usize = 8;
    while (i < 16) : (i += 1) {
        page[i] = 0xCD;
    }

    var chunk = alloc.Chunk.fromBytes(page);
    try testing.expectEqual(@as(usize, 8), chunk.getSize());
    try testing.expectEqualSlices(u8, ([_]u8{0xCD} ** 8)[0..8], chunk.getPayload());
    try testing.expectEqual(@as(usize, 8), chunk.getFooterFromHeader().getSize());
    chunk.setFreeFlag(false);
    try testing.expectEqual(@as(usize, 9), chunk.size);
    try testing.expectEqualSlices(u8, ([_]u8{0xCD} ** 8)[0..8], chunk.getPayload());
    try testing.expectEqual(@as(usize, 9), chunk.getFooterFromHeader().size);
    chunk.setFreeFlag(false);
    try testing.expectEqual(@as(usize, 8), chunk.getSize());
    try testing.expectEqualSlices(u8, ([_]u8{0xCD} ** 8)[0..8], chunk.getPayload());
    try testing.expectEqual(@as(usize, 8), chunk.getFooterFromHeader().getSize());
}

test "AllocTree next chunk" {
    var slice: []u8 = try std.testing.allocator.alloc(u8, alloc.HEADER * 6);
    defer std.testing.allocator.free(slice);
    alloc.Chunk.writeChunk(slice, 8);
    alloc.Chunk.writeChunk(slice[(alloc.HEADER * 3)..], 8);
    var tree = alloc.AllocTree(){ .lower_bound = @ptrToInt(slice.ptr), .upper_bound = @ptrToInt(slice.ptr) + alloc.HEADER * 6 };
    try testing.expectEqual(@as(usize, 8), tree.next(alloc.Chunk.fromBytes(slice)).?.getSize());
}

test "AllocTree prev chunk" {
    var slice: []u8 = try std.testing.allocator.alloc(u8, alloc.HEADER * 6);
    defer std.testing.allocator.free(slice);
    alloc.Chunk.writeChunk(slice, 8);
    alloc.Chunk.writeChunk(slice[(alloc.HEADER * 3)..], 8);
    var tree = alloc.AllocTree(){ .lower_bound = @ptrToInt(slice.ptr), .upper_bound = @ptrToInt(slice.ptr) + alloc.HEADER * 6 };
    try testing.expectEqual(alloc.Chunk{ .size = 8 }, tree.prev(alloc.Chunk.fromBytes(slice[(alloc.HEADER * 3)..])).?.*);
}

test "validate allocator (zig stdlib test thing)" {
    _ = std.mem.validationWrap(alloc.AllocTree(){}).allocator();
}

test "allocate correct size" {
    const zig_is_dumb: usize = 3;

    var ptr = try myalloc.alloc(u8, zig_is_dumb);
    defer myalloc.free(ptr);

    try testing.expectEqual(zig_is_dumb, ptr.len);
}

test "split chunks" {

    //std.debug.print("\nThis is right before the crash in main\n",.{});
    var ptr = try myalloc.alloc(u8, @as(usize, 33));

    //std.debug.print("\nThis is after the big bad crash\n",.{});
    defer myalloc.free(ptr);

    var ptr2 = try myalloc.alloc(u8, @as(usize, 33));
    defer myalloc.free(ptr2);

    try testing.expectEqual(@as(usize, 33), ptr.len);
}

test "reclaim when chunk is freed" {
    var first = try myalloc.alloc(u8, @as(usize, 33));

    var ptr = try myalloc.alloc(u8, @as(usize, 33));
    const addr = @ptrToInt(ptr.ptr);
    myalloc.free(ptr);

    var ptr2 = try myalloc.alloc(u8, @as(usize, 33));
    const addr2 = @ptrToInt(ptr2.ptr);
    myalloc.free(ptr2);

    try testing.expectEqual(addr, addr2);

    myalloc.free(first);
}

test "allocate and reallocate" {
    const original_len: usize = 42;
    const first_ele: u8 = 10;
    const new_len: usize = 100;

    var ptr = try myalloc.alloc(u8, original_len);
    defer myalloc.free(ptr);

    try testing.expectEqual(original_len, ptr.len);

    ptr[0] = first_ele;

    ptr = try myalloc.realloc(ptr, new_len);
    // Didn't move the pointer
    try testing.expectEqual(first_ele, ptr[0]);
    // Didn't lie about the length
    try testing.expectEqual(new_len, ptr.len);
}

test "coalesce freed chunks (tests alloc chunk split)" {
    const original_len: usize = 1024;
    const first_ele: u8 = 10;
    const new_len: usize = 100;

    var ptr = try myalloc.alloc(u8, original_len);
    defer myalloc.free(ptr);
    const ptr_1 = @ptrToInt(ptr.ptr);

    try testing.expectEqual(original_len, ptr.len);

    ptr[0] = first_ele;

    // Resize to free the next chunk
    ptr = try myalloc.realloc(ptr, new_len);
    // Didn't move the pointer
    try testing.expectEqual(first_ele, ptr[0]);
    const ptr_2 = @ptrToInt(ptr.ptr);

    // Allocate a new chunk that should be satisfied by the resized chunk
    var next_ptr = try myalloc.alloc(u8, 100);
    defer myalloc.free(next_ptr);

    try testing.expectEqual(ptr_1, ptr_2);

    // Should be able to do this
    try testing.expectEqual(ptr_1, @ptrToInt(next_ptr.ptr) - 120);
}

test "allocate struct" {
    const Thing = struct {
        x: usize,
        y: f32,
        z: u8,
    };

    var s = try myalloc.create(Thing);
    s.* = Thing{
        .x = 1,
        .y = 2.1,
        .z = 2,
    };
    try testing.expectEqual(Thing{
        .x = 1,
        .y = 2.1,
        .z = 2,
    }, s.*);

    myalloc.destroy(s);
}

test "allocate an ArrayList" {
    var list = std.ArrayList(usize).init(myalloc);

    defer list.deinit();

    try list.append(0);
    try list.append(1);
    try list.append(2);
    try list.append(3);

    try list.appendSlice(&[_]usize{ 4, 5, 6, 7, 8 });

    try list.appendSlice(&[_]usize{ 4, 5, 6, 7, 8, 9, 10, 11 });

    try list.appendSlice(&[_]usize{ 4, 5, 6, 7, 8, 9, 10, 11 });
}

test "allocate an ArrayList with a resize (tests merge and resize chunk split)" {
    var list = std.ArrayList(usize).init(myalloc);
    defer list.deinit();
    try list.appendSlice(&[_]usize{ 4, 5, 6, 7, 8 });
    try list.appendSlice(&[_]usize{ 4, 5, 6, 7, 8, 9, 10, 11 });
    try list.appendSlice(&[_]usize{ 4, 5, 6, 7, 8, 9, 10, 11 });

    list.shrinkAndFree(list.items.len / 2);

    try list.appendSlice(&[_]usize{ 4, 5, 6, 7, 8, 9, 10, 11 });
    try list.appendSlice(&[_]usize{ 4, 5, 6, 7, 8, 9, 10, 11, 4, 5, 6, 7, 8, 9, 10, 11, 4, 5, 6, 7, 8, 9, 10, 11 });
}