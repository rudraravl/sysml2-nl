package CompressiveSensingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type SignalIndex > Integer;
    value type MeasurementCount > Integer;
    value type SparsityLevel > Integer;
    value type CompressionRatio > Real;
    value type ReconstructionError > Real {
        :>> unit = 1; // dimensionless ratio
    }
    value type SignalAmplitude > Real {
        :>> unit = 1;
    }
    value type MatrixEntry > Real {
        :>> unit = 1;
    }
    value type Tolerance > Real {
        :>> unit = 1;
    }

    // ===== Item Definitions =====
    item def HighResolutionSignal {
        attribute dimension : SignalIndex;
        attribute samples : Array(SignalAmplitude, dimension);
    }

    item def SparseBasis {
        attribute size : SignalIndex;
        attribute matrix : Array(Array(MatrixEntry, size), size);
    }

    item def SparseSignal {
        attribute dimension : SignalIndex;
        attribute coefficients : Array(SignalAmplitude, dimension);
        attribute sparsity : SparsityLevel;
    }

    item def SensingMatrix {
        attribute rows : MeasurementCount;
        attribute cols : SignalIndex;
        attribute entries : Array(Array(MatrixEntry, rows), cols);
    }

    item def CompressedMeasurements {
        attribute count : MeasurementCount;
        attribute values : Array(SignalAmplitude, count);
        attribute ratio : CompressionRatio;
    }

    item def ReconstructedSignal {
        attribute dimension : SignalIndex;
        attribute samples : Array(SignalAmplitude, dimension);
    }

    item def ValidationReport {
        attribute error : ReconstructionError;
        attribute passed : Boolean;
        attribute tolerance : Tolerance;
    }

    // ===== Port Definitions =====
    port def HighResSignalOut {
        out item : HighResolutionSignal;
    }
    port def HighResSignalIn {
        in item : HighResolutionSignal;
    }
    port def SparseSignalOut {
        out item : SparseSignal;
    }
    port def SparseSignalIn {
        in item : SparseSignal;
    }
    port def MeasurementsOut {
        out item : CompressedMeasurements;
    }
    port def MeasurementsIn {
        in item : CompressedMeasurements;
    }
    port def RecoveredSparseOut {
        out item : SparseSignal;
    }
    port def RecoveredSparseIn {
        in item : SparseSignal;
    }
    port def ReconstructedOut {
        out item : ReconstructedSignal;
    }
    port def ReconstructedIn {
        in item : ReconstructedSignal;
    }
    port def OriginalSignalRef {
        in item : HighResolutionSignal;
    }
    port def ValidationOut {
        out item : ValidationReport;
    }

    // ===== Requirements =====
    requirement def CompressionEfficiency {
        doc /* The system shall achieve at least a 4-to-1 compression ratio. */
        attribute minRatio : CompressionRatio = 4.0;
        subject ratio : CompressionRatio;
        require ratio >= minRatio;
    }

    requirement def ReconstructionFidelity {
        doc /* The reconstructed signal shall have error below tolerance. */
        attribute maxError : ReconstructionError = 0.05;
        subject error : ReconstructionError;
        require error <= maxError;
    }

    requirement def SparsityPreservation {
        doc /* The sparse encoder shall produce a signal with sparsity below threshold. */
        attribute maxSparsity : SparsityLevel = 64;
        subject sparsity : SparsityLevel;
        require sparsity <= maxSparsity;
    }

    // ===== Parts =====
    part def SignalSource {
        port out signalOut : HighResSignalOut;
        attribute signalDimension : SignalIndex = 256;
        attribute generatedSignal : HighResolutionSignal;

        action def GenerateSignal {
            out generated : HighResolutionSignal;
        }
        exhibit state GenerateBehavior {
            entry; then Generating;
            state Generating;
            transition Generating -> Generating
                when signalOut.item == null
                do send HighResolutionSignal(dimension = signalDimension, samples = Array::generate(signalDimension, 0.0)) to signalOut;
        }
    }

    part def SparseEncoder {
        port in signalIn : HighResSignalIn;
        port out sparseOut : SparseSignalOut;
        attribute basis : SparseBasis;
        attribute inputDimension : SignalIndex = 256;
        attribute outputSparsity : SparsityLevel = 32;

        action def ApplyTransform {
            in input : HighResolutionSignal;
            out sparse : SparseSignal;
            doc /* Apply wavelet transform to produce sparse coefficients. */
        }
        exhibit state EncodeBehavior {
            entry; then Idle;
            state Idle;
            state Encoding;
            transition Idle -> Encoding
                when signalIn.item != null
                do ApplyTransform(input = signalIn.item, sparse = SparseSignal(dimension = inputDimension, coefficients = Array::generate(inputDimension, 0.0), sparsity = outputSparsity));
            transition Encoding -> Idle
                do send sparseOut.item to sparseOut;
        }
    }

    part def RandomProjector {
        port in sparseIn : SparseSignalIn;
        port out measurementsOut : MeasurementsOut;
        attribute sensingMatrix : SensingMatrix;
        attribute measurementCount : MeasurementCount = 64;
        attribute signalDimension : SignalIndex = 256;
        attribute targetRatio : CompressionRatio = 4.0;

        action def Project {
            in sparse : SparseSignal;
            out measurements : CompressedMeasurements;
            doc /* Multiply sensing matrix by sparse signal to obtain compressed measurements. */
        }
        exhibit state ProjectBehavior {
            entry; then Waiting;
            state Waiting;
            state Projecting;
            transition Waiting -> Projecting
                when sparseIn.item != null
                do Project(sparse = sparseIn.item, measurements = CompressedMeasurements(count = measurementCount, values = Array::generate(measurementCount, 0.0), ratio = targetRatio));
            transition Projecting -> Waiting
                do send measurementsOut.item to measurementsOut;
        }
    }

    part def L1Solver {
        port in measurementsIn : MeasurementsIn;
        port out recoveredOut : RecoveredSparseOut;
        attribute tolerance : Tolerance = 1e-6;
        attribute maxIterations : Integer = 1000;
        attribute signalDimension : SignalIndex = 256;

        action def SolveL1Minimization {
            in measurements : CompressedMeasurements;
            in sensingMatrix : SensingMatrix;
            out recovered : SparseSignal;
            doc /* Solve the L1-norm minimization problem to recover the sparsest signal. */
        }
        exhibit state SolveBehavior {
            entry; then Ready;
            state Ready;
            state Solving;
            state Converged;
            state Failed;
            transition Ready -> Solving
                when measurementsIn.item != null
                do SolveL1Minimization(measurements = measurementsIn.item, sensingMatrix = SensingMatrix(rows = measurementsIn.item.count, cols = signalDimension, entries = Array::generate(measurementsIn.item.count, Array::generate(signalDimension, 0.0))), recovered = SparseSignal(dimension = signalDimension, coefficients = Array::generate(signalDimension, 0.0), sparsity = 0));
            transition Solving -> Converged
                when recoveredOut.item != null;
            transition Solving -> Failed
                when recoveredOut.item == null;
            transition Converged -> Ready;
            transition Failed -> Ready;
        }
    }

    part def SignalReconstructor {
        port in recoveredIn : RecoveredSparseIn;
        port out reconstructedOut : ReconstructedOut;
        attribute basis : SparseBasis;
        attribute signalDimension : SignalIndex = 256;

        action def InverseTransform {
            in sparse : SparseSignal;
            out reconstructed : ReconstructedSignal;
            doc /* Apply inverse wavelet transform to recover the original-domain signal. */
        }
        exhibit state ReconstructBehavior {
            entry; then Standby;
            state Standby;
            state Reconstructing;
            transition Standby -> Reconstructing
                when recoveredIn.item != null
                do InverseTransform(sparse = recoveredIn.item, reconstructed = ReconstructedSignal(dimension = signalDimension, samples = Array::generate(signalDimension, 0.0)));
            transition Reconstructing -> Standby
                do send reconstructedOut.item to reconstructedOut;
        }
    }

    part def QualityValidator {
        port in reconstructedIn : ReconstructedIn;
        port in originalRef : OriginalSignalRef;
        port out reportOut : ValidationOut;
        attribute tolerance : Tolerance = 0.05;
        attribute computedError : ReconstructionError = 0.0;

        action def ComputeError {
            in original : HighResolutionSignal;
            in reconstructed : ReconstructedSignal;
            out error : ReconstructionError;
            doc /* Compute normalized L2 reconstruction error. */
        }
        exhibit state ValidateBehavior {
            entry; then Awaiting;
            state Awaiting;
            state Validating;
            state Passed;
            state Failed;
            transition Awaiting -> Validating
                when reconstructedIn.item != null and originalRef.item != null
                do ComputeError(original = originalRef.item, reconstructed = reconstructedIn.item, error = 0.0);
            transition Validating -> Passed
                when computedError <= tolerance
                do send ValidationReport(error = computedError, passed = true, tolerance = tolerance) to reportOut;
            transition Validating -> Failed
                when computedError > tolerance
                do send ValidationReport(error = computedError, passed = false, tolerance = tolerance) to reportOut;
            transition Passed -> Awaiting;
            transition Failed -> Awaiting;
        }
    }

    // ===== System Assembly =====
    part def CompressiveSensingSystem {
        part source : SignalSource;
        part encoder : SparseEncoder;
        part projector : RandomProjector;
        part solver : L1Solver;
        part reconstructor : SignalReconstructor;
        part validator : QualityValidator;

        satisfy CompressionEfficiency by projector.targetRatio;
        satisfy ReconstructionFidelity by validator.computedError;
        satisfy SparsityPreservation by encoder.outputSparsity;

        connection source.signalOut to encoder.signalIn;
        connection encoder.sparseOut to projector.sparseIn;
        connection projector.measurementsOut to solver.measurementsIn;
        connection solver.recoveredOut to reconstructor.recoveredIn;
        connection reconstructor.reconstructedOut to validator.reconstructedIn;
        connection source.signalOut to validator.originalRef;

        exhibit state SystemOperation {
            entry; then Acquiring;
            state Acquiring;
            state Encoding;
            state Compressing;
            state Solving;
            state Reconstructing;
            state Validating;
            state Complete;

            transition Acquiring -> Encoding when encoder.signalIn.item != null;
            transition Encoding -> Compressing when projector.sparseIn.item != null;
            transition Compressing -> Solving when solver.measurementsIn.item != null;
            transition Solving -> Reconstructing when reconstructor.recoveredIn.item != null;
            transition Reconstructing -> Validating when validator.reconstructedIn.item != null;
            transition Validating -> Complete when validator.reportOut.item != null;
            transition Complete -> Acquiring;
        }
    }
}
