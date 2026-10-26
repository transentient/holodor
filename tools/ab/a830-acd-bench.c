/*
 * a830-acd-bench.c — ALU-bound FP32 compute benchmark for Adreno 830 ACD verification
 *
 * Uses EGL_PLATFORM_SURFACELESS_MESA + OpenGL ES 3.1 compute shaders (via Zink/Turnip
 * or native GLES driver) to measure pure FP32 FMA throughput at each pinned GPU OPP.
 *
 * Each thread executes 4096 loop iterations of 8 independent vec4 FMAs
 * (4096 * 8 * 4 * 2 = 262,144 FLOPs/thread).
 * With 4096 workgroups of 64 threads (262,144 threads), one dispatch performs:
 *   262,144 * 262,144 = 68,719,476,736 FLOPs (68.719 GFLOPs).
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl31.h>

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static const char *cs_src =
    "#version 310 es\n"
    "precision highp float;\n"
    "layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;\n"
    "layout(std430, binding = 0) buffer OutBuf {\n"
    "    vec4 data[];\n"
    "};\n"
    "uniform int u_iters;\n"
    "uniform vec4 u_a;\n"
    "uniform vec4 u_b;\n"
    "void main() {\n"
    "    uint idx = gl_GlobalInvocationID.x;\n"
    "    vec4 v0 = vec4(float(idx & 255u) * 0.001 + 1.0);\n"
    "    vec4 v1 = v0 + 0.1;\n"
    "    vec4 v2 = v0 + 0.2;\n"
    "    vec4 v3 = v0 + 0.3;\n"
    "    vec4 v4 = v0 + 0.4;\n"
    "    vec4 v5 = v0 + 0.5;\n"
    "    vec4 v6 = v0 + 0.6;\n"
    "    vec4 v7 = v0 + 0.7;\n"
    "    vec4 a = u_a;\n"
    "    vec4 b = u_b;\n"
    "    for (int i = 0; i < u_iters; i++) {\n"
    "        v0 = v0 * a + b;\n"
    "        v1 = v1 * a + v0;\n"
    "        v2 = v2 * a + v1;\n"
    "        v3 = v3 * a + v2;\n"
    "        v4 = v4 * a + v3;\n"
    "        v5 = v5 * a + v4;\n"
    "        v6 = v6 * a + v5;\n"
    "        v7 = v7 * a + v6;\n"
    "    }\n"
    "    if (v7.x > 1e30) {\n"
    "        data[idx & 1023u] = v0 + v1 + v2 + v3 + v4 + v5 + v6 + v7;\n"
    "    }\n"
    "}\n";

int main(int argc, char **argv) {
    int dispatches = (argc > 1) ? atoi(argv[1]) : 8;
    int iters = (argc > 2) ? atoi(argv[2]) : 2048;
    int groups = 4096;

    PFNEGLGETPLATFORMDISPLAYEXTPROC getPlatformDisplay =
        (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    EGLDisplay dpy = EGL_NO_DISPLAY;
    if (getPlatformDisplay) {
        dpy = getPlatformDisplay(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
    }
    if (dpy == EGL_NO_DISPLAY) {
        dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    }
    if (dpy == EGL_NO_DISPLAY || !eglInitialize(dpy, NULL, NULL)) {
        fprintf(stderr, "eglInitialize failed\n");
        return 1;
    }
    eglBindAPI(EGL_OPENGL_ES_API);

    const EGLint cfg_attr[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_NONE
    };
    EGLConfig cfg;
    EGLint num_cfg = 0;
    eglChooseConfig(dpy, cfg_attr, &cfg, 1, &num_cfg);

    const EGLint ctx_attr[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };
    EGLContext ctx = eglCreateContext(dpy, num_cfg ? cfg : EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, ctx_attr);
    if (ctx == EGL_NO_CONTEXT) {
        fprintf(stderr, "eglCreateContext failed\n");
        return 1;
    }
    if (!eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx)) {
        fprintf(stderr, "eglMakeCurrent failed\n");
        return 1;
    }

    GLuint cs = glCreateShader(GL_COMPUTE_SHADER);
    glShaderSource(cs, 1, &cs_src, NULL);
    glCompileShader(cs);
    GLint ok = 0;
    glGetShaderiv(cs, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024];
        glGetShaderInfoLog(cs, sizeof(log), NULL, log);
        fprintf(stderr, "Shader compile error: %s\n", log);
        return 1;
    }

    GLuint prog = glCreateProgram();
    glAttachShader(prog, cs);
    glLinkProgram(prog);
    glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[1024];
        glGetProgramInfoLog(prog, sizeof(log), NULL, log);
        fprintf(stderr, "Program link error: %s\n", log);
        return 1;
    }
    glUseProgram(prog);

    GLuint ssbo = 0;
    glGenBuffers(1, &ssbo);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssbo);
    glBufferData(GL_SHADER_STORAGE_BUFFER, 1024 * 16, NULL, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);

    glUniform1i(glGetUniformLocation(prog, "u_iters"), iters);
    glUniform4f(glGetUniformLocation(prog, "u_a"), 0.999999f, 0.999998f, 0.999997f, 0.999996f);
    glUniform4f(glGetUniformLocation(prog, "u_b"), 0.000001f, 0.000002f, 0.000003f, 0.000004f);

    /* Warmup */
    glDispatchCompute(groups, 1, 1);
    glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    glFinish();

    double t0 = now_sec();
    for (int d = 0; d < dispatches; d++) {
        glDispatchCompute(groups, 1, 1);
        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
    }
    glFinish();
    double dt = now_sec() - t0;

    double flops_per_dispatch = (double)groups * 64.0 * (double)iters * 8.0 * 4.0 * 2.0;
    double gflops = (flops_per_dispatch * (double)dispatches) / (dt * 1e9);
    printf("GFLOPS=%.2f elapsed=%.4fs renderer=\"%s\"\n",
           gflops, dt, (const char *)glGetString(GL_RENDERER));
    return 0;
}
