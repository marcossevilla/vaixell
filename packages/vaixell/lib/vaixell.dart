/// Checks architecture rules in Dart and Flutter repositories.
library;

export 'src/baseline/baseline.dart' show Baseline, BaselineException;
export 'src/check/check.dart' show Check;
export 'src/check/write_baseline.dart' show WriteBaseline;
export 'src/config/config.dart' show Config, ConfiguredRule, RuleSet;
export 'src/git/git_runner.dart' show GitException;
export 'src/model/model.dart'
    show
        AccessOperator,
        Annotation,
        Argument,
        ArgumentUse,
        Await,
        Call,
        Cast,
        ClassDeclaration,
        CollectionLiteral,
        Constructor,
        DartFile,
        Declaration,
        Enclosed,
        EnumDeclaration,
        Expression,
        ExtensionDeclaration,
        ExtensionTypeDeclaration,
        Field,
        FunctionCall,
        FunctionKind,
        FunctionMember,
        Import,
        ImportKind,
        InstanceCreation,
        Member,
        Method,
        MethodCall,
        MixinDeclaration,
        NullCheck,
        NullCheckUse,
        OtherExpression,
        OtherUse,
        Parameter,
        Parenthesized,
        ReceiverUse,
        Reference,
        Reportable,
        SyntaxError,
        This,
        TopLevelFunction,
        TopLevelVariable,
        TypeAnnotation,
        TypeDeclaration,
        Use;
export 'src/options/config_exception.dart' show ConfigException;
export 'src/options/option_value.dart' show OptionValue;
export 'src/report/github_reporter.dart' show GithubReporter;
export 'src/report/json_reporter.dart' show JsonReporter;
export 'src/report/report.dart' show Report, ReportMode;
export 'src/report/reporter.dart' show Reporter;
export 'src/report/text_reporter.dart' show TextReporter;
export 'src/rules/recommended.dart' show Recommended;
export 'src/rules/rule.dart'
    show
        ChecksDeclarations,
        ChecksExpressions,
        ChecksImports,
        ChecksMembers,
        ChecksTypeAnnotations,
        Finding,
        Rule,
        RuleEntry,
        RuleFactory,
        SkipsDirectories;
export 'src/source/source_tree.dart' show SourceTree;
export 'src/violation/diff_result.dart' show DiffResult;
export 'src/violation/violation.dart' show Severity, Violation;
