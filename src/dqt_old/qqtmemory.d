module dqt.dqtmemory;

private size_t[void*] countMap;

@safe nothrow
void incrementQObjectRef(void* data) {
    size_t* count_ptr = data in countMap;

    if (count_ptr !is null) {
        ++(*count_ptr);
    } else {
        countMap[data] = 1;
    }
}

@safe nothrow
bool decrementQObjectRef(void* data) {
    size_t* count_ptr = data in countMap;

    if (count_ptr !is null) {
        return --(*count_ptr) == 0;
    }

    return true;
}
