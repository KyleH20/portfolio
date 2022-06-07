const std = @import("std");
// The testing module has things like `expectEquall` and other testing helpers.
const testing = std.testing;
// This has `info(), warn(), err()` which will print when running tests.
const log = std.log;
// The mem module has functions for manipulating values, pointers, and slices.
// If you need to convert something to and from bytes look here.
const mem = std.mem;
// All this functionality is available as long as you aren't compiling in release mode.
const debug = std.debug;
// Some math stuff, you may need to find the next power of 2 or not.
const math = std.math;

/// Page size of 64KB, since Windows uses this we all have to use this (linux is 4KB)
const PAGE_SIZE: usize = 64 * 1024;

/// The minimum size of each "chunk" you will break the page into, stick to this or bad stuff will happen...
const MIN_CHUNK_SIZE: usize = HEADER * 4;

/// The size of a header (must be public for tester)
pub const HEADER: usize = @sizeOf(Chunk);
/// The size of a footer (same as header)
const FOOTER: usize = HEADER;
/// The size of a combination of header and footer
const HEAD_FOOT: usize = HEADER + FOOTER;

const AllocError = error{OutOfMemory};

//Helper function that will print all bytes in a slice of bytes
pub fn printSlice(slice: []u8) void {
    debug.print("\n",.{});
    for(slice) |byte|{
        debug.print("|{any}| ",.{byte});
    }
    debug.print("\n",.{});
}

pub const Chunk = struct {
    const Self = @This();

    /// Payload size in bytes, no smaller than 8, we use LSB for free/allocated flag
    size: usize = 0, //this is payload size. It does not include the header/footer. If the user requests 17 bytes. It must be 24 Because it must be evenly divisable by 8

    /// Write the bytes of a chunk into the given slice
    pub fn writeChunk(slice: []u8, len: usize) void {
        var alignedLen = mem.alignForward(len,8);//this is the true size of the payload field. 
        var whatWeAreWritingIThink = mem.toBytes(len); //convert the len that is passed into the function into bytes. This should be aligned to the 8th byte

        var i: usize =0;
        //write the header
        while(i < @sizeOf(usize)): (i+=1) {
            slice[i] = whatWeAreWritingIThink[i];
        
        }
        //write footer
        i = HEADER+alignedLen;//Use this to skip the header and the payload
        //write the footer
        while(i < HEAD_FOOT + alignedLen): (i+=1) {//factor in header, payload, and footer. 
            slice[i] = whatWeAreWritingIThink[@mod(i,whatWeAreWritingIThink.len)]; //ensure wrap around of the 8 byte usize footer.
        }
    }

    /// Obtain a pointer to a `Chunk` from the given bytes
    pub fn fromBytes(bytes: []u8) *Self {
        return @ptrCast(*Chunk,@alignCast(8,&bytes[0]));//First align the bytes of the array bytes. Then convert those bytes using a pointer cast to a Chunk variable.
    }

    /// Obtain a slice to the payload area of `Chunk`
    pub fn getPayload(self: *Self) []u8 {
        
        var intPointerOfSize = @ptrToInt(&self.size);//Get a pointer to the size of the chunk. This is kinda sneaky, I will use this as a launching point from which I will kidnap the PayLoad bytes.
        intPointerOfSize += HEADER;//To get at the bytes of paylaod we must first skip the header. To do this we move the pointer past the header by adding the size of the header in bytes.
        
        //This is an example to indicate what I am talking about. Example taken from test "Chunk.getPayload()"
        //{ 8, 0, 0, 0, 0, 0, 0, 0, 205, 205, 205, 205, 205, 205, 205, 205, 8, 0, 0, 0, 0, 0, 0, 0 }
        //|------------------------|---------------------------------------|-----------------------|
        //         Header                           payload                         footer

        var slice = @intToPtr([*]u8,intPointerOfSize);//convert from int to pointer to an array/ multiple items
        //we can convert multi items pointers to slices. The array should go from start to the end of the payload area.
        //To get the accurate size of payload we call self.getSize()
        return slice[0 .. self.getSize()]; 
    }

    /// Given a slice of a payload, locate the header
    pub fn getHeader(buff: []u8) *Self {

        var pointerToFirstOfBuff = @ptrToInt(&buff[0]);//get a pointer to the first of the buffer. This is so we can go out of bounds without zig clutching its pearls.
        pointerToFirstOfBuff -= HEADER;//backtrack 8 bytes, this is not coincidentally the size of a usize. This will land us at the beginning of our chunk.
        //{ 8, 0, 0, 0, 0, 0, 0, 0, 205, 205, 205, 205, 205, 205, 205, 205, 8, 0, 0, 0, 0, 0, 0, 0 }
        //|------------------------|---------------------------------------|-----------------------|
        //         Header                           payload                         footer
        //                         ^
        //  ^         <- (-8)   Start here
//back track to here
        return @intToPtr(*Chunk,pointerToFirstOfBuff);//go from integer to point to Chunk.
    }

    /// Given a slice of a payload, locate the footer
    pub fn getFooter(buff: []u8) *Self {
        var header = getHeader(buff);//get the header. This is so we can get an accurate size of the payload of this chunk.

        var pointerToFirstOfBuff = @ptrToInt(&buff[0]);//get a pointer/integer to the first of the buffer. This is so we can index out of bounds.
        pointerToFirstOfBuff += header.getSize();//move to the beginning of the footer. This should always be correctly aligned. If not we have a problem on our hands.
        //{ 8, 0, 0, 0, 0, 0, 0, 0, 205, 205, 205, 205, 205, 205, 205, 205, 8, 0, 0, 0, 0, 0, 0, 0 }
        //|------------------------|---------------------------------------|-----------------------|
        //         Header                           payload                         footer
        //                         ^                                       ^
        //                   Start here  (+8) ->                       stop here    

        return @intToPtr(*Chunk,pointerToFirstOfBuff);//convert footer bytes into a chunk.
    }

    /// Get the __footer__ `Chunk` from the __header__ `Chunk`, be careful not to mix this up.
    pub fn getFooterFromHeader(self: *Self) *Self {
        //Is this function a joke?
        var pointerToHeader = @ptrToInt(&self.size);//convert ptr to header into an int so it can be manipulated
        pointerToHeader += HEADER + self.getSize();//skip both the header and the payload to arrive at the footer
        var pointerToFooter = @intToPtr(*Chunk,pointerToHeader);//Convert the footer into a chunk 
        return pointerToFooter;
    }//End of GetFooterFromHeader function

    /// Set the header and footer to free or allocated, don't run on a footer `Chunk`
    /// (0 is free, 1 is allocated)
    pub fn setFreeFlag(self: *Self, free: bool) void {
        if(!free){
            self.size = self.size | 0b1;//if the chunk is meant to be allocated then set the last bit to 1 with an OR.
        }
        else{
            //If the value is meant to be free then set the last value to be a 0 with a bit mask. I KNOW I COULD OF DONE THIS WITH A SHIFT
            var temp = ~@as(usize,1); //converts 1 -> 1111111111111111111111111111111111111111111111111111111111111110
            self.size = self.size & temp;//Use an AND to flip the very last bit zero.
        }

        var pointerToHeader = @ptrToInt(&self.size);
        pointerToHeader += HEADER + self.getSize();//move past the header and the payload.
        var pointerToFooter = @intToPtr(*Chunk,pointerToHeader);//convert from integer to pointer to a footer
        pointerToFooter.size = self.size;//set the size of the footer to the correct value. This will be the same value as the header to that chunk
    }//end of setFreeFlag function

    /// Returns whether this `Chunk` is free (0 is free, 1 is allocated)
    pub fn isFree(self: *Self) bool {
        //I really did try to find a better way then this. I just could not.
        switch(self.size & 0b1){//this should get the first bit of the size value. This should tell us if its free or not.
            0 => return true,
            1 => return false,
            else => return false
        }//end of switch
    }//end of isFree

    /// Returns the chunk size without the alloc/free flag
    pub fn getSize(self: *Self) usize {
        var theValue = (self.size >> 1) << 1;
        return theValue; //shift right 1, shift left 1. This gets rid of whatever is at position [0] in size
    }//end of getSize function
};//end of chunk



/// In Zig this compiletime function is evaluted before runtime, this effectivly is just a struct.
pub fn AllocTree() type {
    return struct {
        // This allows you to refer to the anonymous struct
        const Self = @This();

        /// The will ask the system for memory, it is up to you to keep track of it.
        page_alloc: mem.Allocator = std.heap.page_allocator,

        /// Bounds of the allocated page
        lower_bound: usize = 0,
        upper_bound: usize = 0,

        /// Some way to track all that allocation.
        memory: ?[]u8 = null,

        /// Given a pointer to a `Chunk` return the pointer to the previous `Chunk`.
        ///
        /// This is a method of `AllocTree` because you need to make sure you are within the bounds
        /// of your data buffer.
        pub fn prev(self: Self, curr_header: *Chunk) ?*Chunk {
            var pointerToHeader = @ptrToInt(curr_header);//get a pointer to the chunk as an integer
            pointerToHeader -= FOOTER;//This now points to the previous chunks footer

            //If we are beyond the lower bound of our memory page then return a null.
            if(self.lower_bound > pointerToHeader){
                return null;
            }
            var pointerToPrevChunkFooter = @intToPtr(*Chunk,pointerToHeader);//convert from int to pointer to prevous chunks footer
            pointerToHeader -= pointerToPrevChunkFooter.getSize();//get the size of the payload of the chunk whos footer we are now looking at
            pointerToHeader -= HEADER;//get to the start of that chunk
            //If we are beyond the lower bound of our memory page then return a null.
            if(self.lower_bound > pointerToHeader){
                return null;
            }
            //Else we are not beyond the lower bounds of our memory page and we should convert our integer into a pointer to a chunk
            else{
                var pointerToFooter = @intToPtr(*Chunk,pointerToHeader);//we should be at the first byte of the next chunk. Convert from integer to pointer to chunk
                return pointerToFooter;
            }
        }

        /// Given a pointer to a `Chunk` return the pointer to the next `Chunk`.
        ///
        /// This is a method of `AllocTree` because you need to make sure you are within the bounds
        /// of your data buffer.
        pub fn next(self: Self, curr_header: *Chunk) ?*Chunk {
            var pointerToHeader = @ptrToInt(curr_header);//get a pointer to the chunk as an integer
            pointerToHeader += HEAD_FOOT + curr_header.getSize();//skip by the HEADER, the FOOTER, and the PAYLOAD of our current chunk. This should bring us to the starting position of the next chunk.
            if(self.upper_bound < pointerToHeader){//If we are beyond the upper bounds of our memory page return null.
                return null;
            }
            else{//else convert our integer pointer into a pointer to a chunk.
                var pointerToFooter = @intToPtr(*Chunk,pointerToHeader);//we should be at the first byte of the next chunk. Convert from integer to pointer to chunk
                return pointerToFooter;
            }
        }

        //Helper function that given a slice will try to print all the chunks in that slice.
        pub fn printAllTheChunks(self: Self, slice: []u8) void{            
            debug.print("\n----------------------------------------------------------------------------------------------------------------------------------------------\n",.{});
            var i: usize = 1;
            var nextChunk: ?*Chunk = Chunk.fromBytes(slice);
            while(nextChunk != null): (nextChunk = self.next(nextChunk.?)){
                if(nextChunk.?.isFree()){
                    debug.print("| Chunk {d} Size: {d} alloc: F| ",.{i,nextChunk.?.getSize()});
                }else{
                    debug.print("| Chunk {d} Size: {d} alloc: A| ",.{i,nextChunk.?.getSize()});
                }
                i+=1;
            }
            debug.print("\n----------------------------------------------------------------------------------------------------------------------------------------------\n",.{});
        }


        //This function is passed self so it has access to the page, and the different self functions like .next()
        //This function is pass a pointer to the current chunk we are on and the new len. 
        //This new len will be used to create a new chunk at the position of currentChunk
        //The remaining space inside of the old chunk will be used to create a new smaller chunk
        //we will return the payload of the new chunk we created that is allocated. This is the one with length = len //Comment on a comment; this was a mistake. Should of returned the acutal chunk now just the payload
        //The other new chunk will not be returned but can be discovered by our alloc function later to be reused
        pub fn split(self: *Self, currentChunk: *Chunk, len: usize)AllocError![]u8 {            
            var oldValue: usize = currentChunk.getSize();//grab the old free chunk payload size
            //|-------------------------|-----------------------------------------------------------------------------|--------------------------------------|
            //Possible allocated chunk  ^                   Current free chunk/old free chunk                                    Possible allocated chunk
            //                          |
            //                  This is the position we want to start at
            //                                  \
            //Starting point of our new chunk    \                  This makes the pointer relative
            //        v                           v                             v
            var startPointSlice = self.memory.?[(@ptrToInt(currentChunk)-self.lower_bound)..];//get a slice starting at the beginning of the old free chunk.
            Chunk.writeChunk(startPointSlice,mem.alignForward(len,8));//Write newly allocated chunk
            currentChunk.setFreeFlag(false);//ensure the new chunk is not free

            //get the next chunk, this is going to be free
            var newFreeChunk = self.next(currentChunk);
            //Like the previous chunk writing we need to get a slice to where we will begin the writing
            //                                                \            Ensure the start point is relative
            //                                                 \                            |
            //                                                  v                           v
            var startPointSliceOfNewFreeChunk = self.memory.?[(@ptrToInt(newFreeChunk)-self.lower_bound)..];

            //oldValue - (the new allocated chunks payload) + (the total size of the header and footer for the new allocated chunk).
            //                                                                  \
            //write to the preivously calculated posiiton                        \
            //                       v                                            v
            Chunk.writeChunk(startPointSliceOfNewFreeChunk,mem.alignForward(oldValue-(mem.alignForward(len,8)+HEAD_FOOT),8));

            //Make sure the new chunk is free (This should happen automatically because the size should be a multiple of 8)
            newFreeChunk.?.setFreeFlag(true);

            //Return ONLY the payload. This means we shave off the HEADER and the FOOTER. 
            return startPointSlice[HEADER..len+FOOTER];
        }

        //this is a helper function for merging. It will be provided pointers to two chunks. 
        //The second chunk will be merged into the first.
        //This will return nothing but possibly an error.
        pub fn merge(self: Self, chunk1: *Chunk, chunk2: *Chunk) !void {
            _ = self;
            var chunk1AsBytes = @ptrCast([*]u8,chunk1);//turn chunk1 into an array of bytes
            var newSize = (2*HEAD_FOOT)+(chunk1.getSize() + chunk2.getSize());//get the total size of the chunk1 array

            var chunk1AsSlice = chunk1AsBytes[0 .. newSize];//turn chunk1AsBytes into a slice by using the newSize veriable

            //We will re-use writeChunk as it will both create a header and a footer for us.
            Chunk.writeChunk(chunk1AsSlice,newSize-(HEAD_FOOT));//let writeChunk do all our dirty work for us.

            //as the new chunk will be "allocated" we must immedately deallocate it
            chunk1.setFreeFlag(true);

        }

        pub fn alloc(self: *Self, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize,) AllocError![]u8 {
            // This ignores the argument, you will probably use most of them.
            _ = self;
            _ = len;
            _ = ptr_align;
            _ = len_align;
            // Don't worry about this one, it's for stack traces when alloc/free's fail
            _ = ret_addr;


            //This function will basically go through and ensure that we have already created the page where we will be writing chunks
            //If the page is not created then we will
            //We will also create the chunk that we want to.
            //Have we created the page yet?
            if(self.memory == null){//No!
                //create memory
                var thePage = try self.page_alloc.alloc(u8, PAGE_SIZE);// This is how you ask for a whole page, we are going to hardcode that to 64KB.
                self.lower_bound = @ptrToInt(&thePage[0]);
                self.upper_bound = @ptrToInt(&thePage[thePage.len-1]);
                self.memory = thePage;

                //we are now done creating memory. 

                //Now create the first non-free chunk. After Create the first free chunk
                Chunk.writeChunk(self.memory.?,mem.alignForward(len,8));
                var tempChunk = Chunk.fromBytes(self.memory.?);
                tempChunk.setFreeFlag(false);

                //I better comment this pretty nice.
                //We want to write the chunk after the inital chunk. This is going to be a free chunk. To do this we first need
                //to know where to start writing the first chunk
                //So we will call self.next and pass it the first chunk. This will return the next chunk as if it already exists. 
                var pointerToNextChunk = self.next(tempChunk);

                //We will then turn this chunk pointer into an integer, this is so we can do math with it
                var integerPointerOfNextChunk = @ptrToInt(pointerToNextChunk);
                
                //This is where the big brains come in 
                //We will begin writing the next chunk. Chunk.writeChunk() takes a slice: []u8 and a length of usize
                //The slice must start at where we will begin writing the chunk.
                //And our slice is self.memory, which is an array in heap. It starts at 0 and goes to 64*1024
                //And our position in the heap is relative to the position in the array
                //So to calculate the positon in the array correct, we take our position in the heap (our pointer) minues the start of the heap (our lower bound)
                //in semi actual code this looks like: (integerPointerOfNextChunk - self.lower_bound) This is our starting position in the array
                //
                //Now onto the second thing we must pass into writeChunk() the length of storage
                //This must be what space we have left after the initalization of the first chunk plus a header and a footer for our free chunk
                //This is going to look like this: Rest_Of_Heap - (Header+Footer)  
                //But how do we calculate Rest_Of_Heap I hear you ask, o me in the morning//Or me a few days later as it were.
                //Rest_Of_Heap = self.upper_bound+1 - integerPointerOfNextChunk
                //This is because integerPointerOfNextChunk when not relative to the self.memory struct is the ending position of the prevous chunk
                //so its like this: Header + Payload + Footer | +Header ---------- +Footer
                //                 |--------------------------|---------------------------|
                //                      old chunk                   new chunk with unknown payload size
                //                                              Essencially telling writeChunk() where to stop
                //                     |----------------------------------------------------------|
                var freeChunkStorage = (self.upper_bound+1) - (HEAD_FOOT+integerPointerOfNextChunk);
                //This is the size of the previous chunk (HEAD+FOOT+integerPointerOfNextChunk)
                //Minus the total size that we have which is self.upperBound 
                //                            This is telling the writeChunk() where to start     
                //                            |----------------------------------------------|  
                Chunk.writeChunk(self.memory.?[integerPointerOfNextChunk - self.lower_bound..], freeChunkStorage);//write the acutal chunk.
                pointerToNextChunk.?.setFreeFlag(true);

                return self.memory.?[HEADER..HEADER+len];
            }
            //if we already have memory stored, this means that we already have at least 1 chunk allocated.
            else{//Memory already stored
                var currentChunk: ?*Chunk = Chunk.fromBytes(self.memory.?);//get the inital chunk
                while(currentChunk != null): (currentChunk = self.next(currentChunk.?)){//go through each chunk
                    if(currentChunk.?.isFree()){
                        if(len < currentChunk.?.getSize()/2 ){//if the len is less than half the free chunk we should split the chunk
                            //split it
                            return self.split(currentChunk.?,len);//len will be aligned in this function
                        }//end of spliting the chunk
                        else if(len > currentChunk.?.getSize()){//if the current chunk is less than our len then we must move to the next free chunk
                            continue;
                        }//end of free chunk does not have enough space
                        else{
                            //we should allocate the entire block
                            var startPointSlice = self.memory.?[(@ptrToInt(currentChunk)-self.lower_bound)..];
                            Chunk.writeChunk(startPointSlice,mem.alignForward(len,8));
                            currentChunk.?.setFreeFlag(false);
                            return startPointSlice[HEADER..HEADER+len];//return only payload. Exclude header and footer
                        }//end of allocate the whole chunk
                        return self.split(currentChunk.?,len);//<- safe guard. I think unreachable
                    }//end of if the current chunk is free
                }//end of while loop
                //If we go through all the chunks and we still cannot find one that meets our requirments. We should create a new page and begin writing there
                //but since we are not doing that I will return that we are out of memory.
                return error.OutOfMemory;
            }//end of if memory already exists
        }//end of alloc function

        pub fn resize(self: *Self, old_mem: []u8, old_align: u29, new_size: usize, len_align: u29, ret_addr: usize,) ?usize {
            _ = self;
            _ = old_mem;
            _ = old_align;
            _ = new_size;
            _ = len_align;
            _ = ret_addr;
            // You cannot move where `old_mem` points to, so there are three cases this method does stuff
            //   1. you are shrinking memory `old_mem.len > new_size`
            //   2. you are resizing to the same size `old_mem.len == new_size`
            //   3. you are growning memory but not larger than a block or forward merge free blocks ie.
            //
            // |---used---|--old_mem--|-------free------|
            //            |--------new_size------|
            //
            // So the `old_mem` stays but is enlarged with forward mergable chunk

            var chunk = Chunk.getHeader(old_mem);

            //if the new size is smaller than the old size we should shrink the chunk.
            if(chunk.getSize() > new_size){
                //if the newsize is less than half the old size we should call split on it
                if(new_size < chunk.getSize()/2){
                    //This will split our old chunk into two new ones
                    _ = self.split(chunk, mem.alignForward(new_size,8)) catch{ debug.print("Something went wrong in new_size less than old size split.\n",.{}); return null;};
                    //Not sure if this is what we should return yet
                    return new_size;
                }//end of half chunk
                //if the size is not less than half then we should not split. instead we will return the whole size.
                return chunk.getSize();
            }//end of if the chunk should be shrunk.
            //If the newsize is the same as the old size then we will simply return on the old size
            if(chunk.getSize() == new_size){
                return chunk.getSize();
            }

            //If chunk needs to be larger
            if(chunk.getSize() < new_size){
                var alignedNewSize = mem.alignForward(new_size,8);
                //This is the extra size we need
                var extraSizeNeeded = alignedNewSize - chunk.getSize();

                var nextChunk = self.next(chunk);
                //If the next chunk is not null continue
                if(nextChunk != null){
                    //If the next chunk is free
                    if(nextChunk.?.isFree()){
                        //if the extra size we need is less than half the next chunk then we should split that chunk up
                        if(extraSizeNeeded < (nextChunk.?.getSize()/2) ){
                            //spliting the next chunk up into two. The first section will be equal to length extraSizeNeeded-HEAD_FOOT.
                            //This is because the merge function will cannabilize the Header and Footer into the payload size of our old
                            //chunk as well as the payload size of the new chunk
                            //So the total size of the new chunk we should create would be extraSizeNeeded - header - footer 
                            var payloadOfSplitChunk: []u8 = self.split(nextChunk.?,extraSizeNeeded-HEAD_FOOT) catch{return null;};

                            //Since split() returns only the bytes of payload we need to convert that into the header/Chunk
                            var splitChunk = Chunk.getHeader(payloadOfSplitChunk);//desig flaw of split() that I will not rectify
                            
                            //Now that we have both the old chunk and the new chunk we can merge them together.
                            self.merge(chunk,splitChunk) catch{return null;};
                            return new_size;
                        }
                        //if the the extra length we need is less than or equal to the next chunks size. We should simply merge them together.
                        else if(extraSizeNeeded <= nextChunk.?.getSize()){
                            self.merge(chunk,nextChunk.?) catch{return null;};
                            return new_size;
                        }
                        //If the extra size we need cannot be found in the next chunk. We have failed and should return null
                        else{
                            return null;
                        }
                    }//end of if the next chunk is free
                    //If the next chunk is not free there is nothing to be done and we should return null
                    else{
                        return null;
                    }
                }//end of if the next chunk exists

                //If the next chunk does not exist then the operation cannot be completed
                else{
                    return null;
                }   
            }//end of if the new size is larger than old size
            unreachable;//if we have gotten to this point (which cant happen) we should crash
        }

        pub fn free(self: *Self, buf: []u8, buf_align: u29, ret_addr: usize,) void {
            _ = self;
            _ = buf;
            _ = buf_align;
            _ = ret_addr;

            //get the first header of the chunk, should be the only header
            var theChunk = Chunk.getHeader(buf);
            //set the free flag to be true of that header. This frees the chunk.
            Chunk.setFreeFlag(theChunk,true);

            //This entire next section we merge the different freed chunks around the chunk we just freed.
            //In this section we will grab the next chunk and check to see if we should merge them together. If so, merge. 
            var chunkAfter = self.next(theChunk);
            //Does the next chunk not exist? Yes? Oh dear.
            if(chunkAfter == null){
                //Do nothing
            }
            else if(chunkAfter.?.isFree() == true){
                //merge the two chunks with "theChunk" being the lead.
                try self.merge(theChunk,chunkAfter.?);
            }

            //Now we will check the previouls chunk.alloc
            var previousChunk = self.prev(theChunk);

            if(previousChunk == null ){
                //Do nothing
            }
            else if(previousChunk.?.isFree() == true){
                try self.merge(previousChunk.?,theChunk);//merge with previous chunk leading. The chunk before must lead.
            }

            // If the whole page can be freed do it like this
            //
            // Remember you can only free the whole thing if all chunks are also free
            //
            // |-------------------page------------------|
            // |---chunk---|--chunk--|--chunk--|--chunk--|
            // |-curr_free-|-------------free------------|
            //
            // This whole page could be freed once `curr_free` is checked

            //Make sure the memory has not already been freed. I believe this should never happen
            if(self.memory != null){
                //get the first header of the memory
                var veryFirstChunk = Chunk.fromBytes(self.memory.?);
                //get the second header of the memory
                var verySecondChunk = self.next(veryFirstChunk);
                //If the second header is NULL this means that the first header was the ONLY header. This means that all chunks in the page are free
                //IF all the chunks in the page are free, this means the entire page is basically free
                //This means we should free the entire page
                if(verySecondChunk == null ){
                    return;
                }//end of if the whole block is free
            }//end of if memory hasnt already been freed somehow
        }//end of free function

        /// This turns your allocator into what Zig expects.
        pub fn allocator(self: *Self) mem.Allocator {
            return mem.Allocator.init(self, alloc, resize, free);
        }
    };//end of a rather large struck
}//end of the function allocTree
