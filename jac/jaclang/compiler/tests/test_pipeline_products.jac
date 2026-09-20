"""Product scheduling preserves cancellation and live fact prerequisites."""

import os;
import from tempfile { TemporaryDirectory }
import threading;
import from unittest.mock { patch }
import jaclang.compiler.driver.pass_driver as pass_driver;
import from jaclang.compiler.driver.pipeline { require_product, CompilationProduct }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact, TaskState }
import from jaclang.compiler.driver.program { JacProgram }


test "cancelled flow does not fabricate CFG facts or schedule analysis" {
    with TemporaryDirectory() as temp_dir {
        program = JacProgram();
        path = os.path.join(temp_dir, "pipeline_cancel_9151.jac");
        token = threading.Event();
        token.set();
        module = program.parse_str(
            "def answer() -> int { return 42; }\n", path, cancel_token=token
        );
        program.options.cancel_token = token;

        assert not require_product(
            program, module, CompilationProduct.ANALYSIS, cancel_token=token
        );
        assert not program.analysis.analyses_run.provides(
            module, AnalysisFact.CFG_SUCC
        );
        assert not program.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF);
        flow_task = program.analysis.product_tasks[id(module)][
            CompilationProduct.FLOW
        ];
        analysis_task = program.analysis.product_tasks[id(module)][
            CompilationProduct.ANALYSIS
        ];
        assert flow_task.state == TaskState.CANCELLED , flow_task.state;
        assert analysis_task.state == TaskState.CANCELLED , analysis_task.state;

        token.clear();
        assert require_product(program, module, CompilationProduct.ANALYSIS);
        assert program.analysis.analyses_run.provides(module, AnalysisFact.CFG_SUCC);
        assert program.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF);
        assert flow_task.state == TaskState.SUCCEEDED , flow_task.state;
        assert analysis_task.state == TaskState.SUCCEEDED , analysis_task.state;
    }
}

test "mid-schedule cancellation leaves products retryable" {
    with TemporaryDirectory() as temp_dir {
        program = JacProgram();
        path = os.path.join(temp_dir, "pipeline_cancel_mid_schedule_9151.jac");
        token = threading.Event();
        module = program.parse_str(
            "def answer() -> int { return 42; }\n", path, cancel_token=token
        );
        program.options.cancel_token = token;
        original = pass_driver.run_pass;

        def cancel_after_flow(
            pass_cls: type, ir_in: any, prog: JacProgram, **kwargs: any
        ) -> any {
            result = original(pass_cls, ir_in, prog, **kwargs);
            if pass_cls.__name__ == "CFGBuildPass" {
                token.set();
            }
            return result;
        }

        with patch.object(pass_driver, "run_pass", cancel_after_flow) {
            assert not require_product(
                program,
                module,
                CompilationProduct.ANALYSIS,
                cancel_token=token
            );
        }

        assert token.is_set();
        assert program.analysis.analyses_run.provides(module, AnalysisFact.CFG_SUCC);
        assert not program.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF);
        flow_task = program.analysis.product_tasks[id(module)][
            CompilationProduct.FLOW
        ];
        analysis_task = program.analysis.product_tasks[id(module)][
            CompilationProduct.ANALYSIS
        ];
        assert flow_task.state == TaskState.CANCELLED , flow_task.state;
        assert analysis_task.state == TaskState.CANCELLED , analysis_task.state;
        completed = program.analysis.completed_passes[id(module)];
        assert "CFGBuildPass" not in completed , completed;

        token.clear();
        assert require_product(program, module, CompilationProduct.ANALYSIS);
        assert program.analysis.analyses_run.provides(module, AnalysisFact.CFG_SUCC);
        assert program.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF);
        assert flow_task.state == TaskState.SUCCEEDED , flow_task.state;
        assert analysis_task.state == TaskState.SUCCEEDED , analysis_task.state;
    }
}
