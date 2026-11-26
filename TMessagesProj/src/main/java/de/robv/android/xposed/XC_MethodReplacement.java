package de.robv.android.xposed;

/** Temporary compile-time stub (not exteraGram code). */
public abstract class XC_MethodReplacement extends XC_MethodHook {
    public XC_MethodReplacement() {
        super();
    }

    public XC_MethodReplacement(int priority) {
        super(priority);
    }

    @Override
    protected final void beforeHookedMethod(MethodHookParam param) throws Throwable {
        try {
            param.setResult(replaceHookedMethod(param));
        } catch (Throwable t) {
            param.setThrowable(t);
        }
    }

    @Override
    protected final void afterHookedMethod(MethodHookParam param) throws Throwable {
    }

    protected abstract Object replaceHookedMethod(MethodHookParam param) throws Throwable;
}
