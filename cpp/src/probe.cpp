#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

namespace godot {
class CppProbe : public RefCounted {
    GDCLASS(CppProbe, RefCounted)

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("add", "a", "b"), &CppProbe::add);
    }

public:
    int64_t add(int32_t a, int32_t b) const {
        return static_cast<int64_t>(a) + static_cast<int64_t>(b);
    }
};

void initialize_game_cpp(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        GDREGISTER_CLASS(CppProbe);
    }
}

void uninitialize_game_cpp(ModuleInitializationLevel) {}
} // namespace godot

extern "C" {
GDExtensionBool GDE_EXPORT game_cpp_init(
        GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library,
        GDExtensionInitialization *initialization) {
    godot::GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(godot::initialize_game_cpp);
    init.register_terminator(godot::uninitialize_game_cpp);
    init.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
