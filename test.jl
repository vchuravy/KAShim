#!/usr/bin/env julia
using Libdl

dlopen("./libkashim", RTLD_GLOBAL)

struct Payload
    handle::Ptr{Cvoid}
    barrier::Ptr{Cvoid}
    function Payload(handle::Ptr{Cvoid})
        barrier = ccall(:ka_barrier_malloc, Ptr{Cvoid}, ())
        ccall(:ka_barrier_init, Cint, (Ptr{Cvoid}, Cuint), barrier, 2)
        new(handle, barrier)
    end
end

# Outside event the one we want to synchronize upon
cpu_event =  Base.Threads.Event()

# AsyncCondition is edge-triggered. We need to turn it into
# a level-triggered event. So we set up a barrier and have the AsyncCondition
# notify that, instead of waitingon the AsyncCondition directly.
barrier = Base.Threads.Event() # level-triggered
async = Base.AsyncCondition() do cond # edge-triggered
    notify(barrier)
    close(cond) # stop waiting for another notifycation
end
payload = Ref(Payload(async.handle))
@info "Setting up done"

# Task that is used to perform the waiting on cpu_event and the subsequent
# blocking barrier. We perhaps could use `@threadcall` to use LibUV threads
# to do the barrier_wait, but that barrier_wait should be cheap since the 
# callback thread has already reached it.
T = Threads.@spawn begin
    GC.@preserve async payload begin
        # wait on MT-safe barrier
        @info "Waiting on notify"
        wait(barrier) # suspend ourselves until then
        @info "Received notify"

        # wait on actual work
        try
            @info "Waiting on cpu_event"
            wait(cpu_event)
        catch err
            bt = catch_backtrace()
            @error "Error thrown during ait on cpu_event" _ex=(err, bt)
        finally
            @info "Notifying callback"
            # now notify callback
            ka_barrier = payload[].barrier
            if ccall(:ka_barrier_wait, Cint, (Ptr{Cvoid},), ka_barrier) > 0
                ccall(:ka_barrier_destroy, Cvoid, (Ptr{Cvoid},), ka_barrier)
                ccall(:ka_barrier_free, Cvoid, (Ptr{Cvoid},), ka_barrier)
            end
            @info "done"
        end
    end
    return nothing
end

# This is the callback we want to synchronize with
# emulate a C-thread calling this by using `@threadcall` which
# executes a callback on the LibUV threadpool.
T2 = @async begin
    @info "threadcall callback"
    Base.@threadcall(:ka_callback, Cvoid, (Ptr{Cvoid},), payload)
    @info "callback done"
end

@info "notifying outside event"
notify(cpu_event)
@info "waiting upon T"
wait(T)
@info "waiting upon T2"
wait(T2)
@info "all done!"




