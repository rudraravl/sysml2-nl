package 'Compressive Sensing System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    attribute def SparseSignal;
    attribute def CompressedMeasurement;
    attribute def ReconstructedSignal;
    attribute def MeasurementMatrixData;
    attribute def BasisTransform;
    attribute def OptimizationResult;

    value def SignalDimension :> ScalarValues::Integer;
    value def MeasurementCount :> ScalarValues::Integer;
    value def SparsityLevel :> ScalarValues::Integer;
    value def CompressionRatio :> ScalarValues::Real;
    value def ReconstructionError :> ScalarValues::Real;
    value def SignalAmplitude :> ScalarValues::Real;
    value def MatrixCoherence :> ScalarValues::Real;
    value def IterationCount :> ScalarValues::Integer;

    item def OriginalSignal {
        attribute dimension : SignalDimension;
        attribute sparsity : SparsityLevel;
        attribute values : SignalAmplitude[*];
        attribute timestamp : TimeValue;
    }

    item def CompressedData {
        attribute measurementCount : MeasurementCount;
        attribute measurements : ScalarValues::Real[*];
        attribute acquisitionTime : TimeValue;
    }

    item def ReconstructedData {
        attribute dimension : SignalDimension;
        attribute recoveredValues : ScalarValues::Real[*];
        attribute errorMetric : ReconstructionError;
        attribute reconstructionTime : TimeValue;
    }

    item def SensingMatrix {
        attribute rows : MeasurementCount;
        attribute columns : SignalDimension;
        attribute matrixElements : ScalarValues::Real[*];
        attribute coherence : MatrixCoherence;
        attribute isRandomized : ScalarValues::Boolean;
    }

    item def SparseBasis {
        attribute basisType : ScalarValues::String;
        attribute dimension : SignalDimension;
        attribute coefficients : ScalarValues::Real[*];
    }

    part def SignalSource {
        out port signalOut;
        attribute signalDimension : SignalDimension;
        attribute targetSparsity : SparsityLevel;
    }

    part def SparseEncoder {
        in port signalIn;
        out port sparseOut;
        attribute transformBasis : SparseBasis;
        attribute sparsityThreshold : ScalarValues::Real;
    }

    part def RandomProjector {
        in port sparseIn;
        out port measurementsOut;
        attribute sensingMatrix : SensingMatrix;
        attribute projectionRate : CompressionRatio;
    }

    part def L1Solver {
        in port measurementsIn;
        out port solutionOut;
        attribute convergenceTolerance : ScalarValues::Real;
        attribute maxIterations : IterationCount;
        attribute regularizationParameter : ScalarValues::Real;
    }

    part def SignalReconstructor {
        in port sparseCoefficientsIn;
        out port reconstructedOut;
        attribute inverseBasis : SparseBasis;
    }

    part def QualityValidator {
        in port originalIn;
        in port reconstructedIn;
        out port metricsOut;
        attribute errorThreshold : ReconstructionError;
    }

    action def TransformToSparseBasis {
        in signal : OriginalSignal;
        in basis : SparseBasis;
        out sparseCoefficients : ScalarValues::Real[*];
        out sparsityLevel : SparsityLevel;
    }

    action def GenerateRandomMatrix {
        in rows : MeasurementCount;
        in columns : SignalDimension;
        out matrix : SensingMatrix;
    }

    action def ProjectToMeasurements {
        in sparseData : ScalarValues::Real[*];
        in matrix : SensingMatrix;
        out compressed : CompressedData;
    }

    action def SolveL1Optimization {
        in measurements : CompressedData;
        in matrix : SensingMatrix;
        in tolerance : ScalarValues::Real;
        in maxIter : IterationCount;
        out solution : ScalarValues::Real[*];
        out iterations : IterationCount;
    }

    action def InverseTransform {
        in sparseCoefficients : ScalarValues::Real[*];
        in basis : SparseBasis;
        out reconstructed : ReconstructedData;
    }

    action def ComputeReconstructionError {
        in original : OriginalSignal;
        in reconstructed : ReconstructedData;
        out errorNorm : ReconstructionError;
        out relativeError : ScalarValues::Real;
    }

    action def PerformCompressiveSensing {
        in inputSignal : OriginalSignal;
        in targetMeasurements : MeasurementCount;
        in sparsityConstraint : SparsityLevel;
        in convergenceTol : ScalarValues::Real;
        out outputSignal : ReconstructedData;
        out qualityMetric : ReconstructionError;

        first start;
        then merge beginProcess;

        then action encodeSignal : TransformToSparseBasis {
            in signal = inputSignal;
            in basis : SparseBasis;
            out sparseCoefficients;
            out sparsityLevel;
        }

        then action generateMatrix : GenerateRandomMatrix {
            in rows = targetMeasurements;
            in columns = inputSignal.dimension;
            out matrix;
        }

        then action projectData : ProjectToMeasurements {
            in sparseData = encodeSignal.sparseCoefficients;
            in matrix = generateMatrix.matrix;
            out compressed;
        }

        then action solveOptimization : SolveL1Optimization {
            in measurements = projectData.compressed;
            in matrix = generateMatrix.matrix;
            in tolerance = convergenceTol;
            in maxIter = 1000;
            out solution;
            out iterations;
        }

        then action reconstructSignal : InverseTransform {
            in sparseCoefficients = solveOptimization.solution;
            in basis = encodeSignal.basis;
            out reconstructed;
        }

        then action validateQuality : ComputeReconstructionError {
            in original = inputSignal;
            in reconstructed = reconstructSignal.reconstructed;
            out errorNorm;
            out relativeError;
        }

        then decide;
            if validateQuality.errorNorm < convergenceTol then acceptResult;
            if validateQuality.errorNorm >= convergenceTol then refineParameters;

        action refineParameters {
            then assign sparsityConstraint := sparsityConstraint + 5;
        }
        then beginProcess;

        action acceptResult {
            then assign outputSignal := reconstructSignal.reconstructed;
            then assign qualityMetric := validateQuality.errorNorm;
        }
        then done;
    }

    part def CompressiveSensingSystem {
        doc /* 
            A compressive sensing system that acquires signals using significantly 
            fewer measurements than traditional Nyquist sampling by exploiting signal 
            sparsity. The system performs random linear projections of sparse signals, 
            then reconstructs the original signal through L1-norm optimization.
        */

        attribute systemDimension : SignalDimension = 2048;
        attribute measurementCount : MeasurementCount = 512;
        attribute expectedSparsity : SparsityLevel = 100;
        attribute compressionRatio : CompressionRatio = 0.25;
        attribute errorTolerance : ReconstructionError = 0.01;

        part source : SignalSource {
            out port signalOut;
            attribute signalDimension = CompressiveSensingSystem::systemDimension;
            attribute targetSparsity = CompressiveSensingSystem::expectedSparsity;
        }

        part encoder : SparseEncoder {
            in port signalIn;
            out port sparseOut;
            attribute sparsityThreshold = 0.001;
        }

        part projector : RandomProjector {
            in port sparseIn;
            out port measurementsOut;
            attribute projectionRate = CompressiveSensingSystem::compressionRatio;
        }

        part solver : L1Solver {
            in port measurementsIn;
            out port solutionOut;
            attribute convergenceTolerance = CompressiveSensingSystem::errorTolerance;
            attribute maxIterations = 1000;
            attribute regularizationParameter = 0.001;
        }

        part reconstructor : SignalReconstructor {
            in port sparseCoefficientsIn;
            out port reconstructedOut;
        }

        part validator : QualityValidator {
            in port originalIn;
            in port reconstructedIn;
            out port metricsOut;
            attribute errorThreshold = CompressiveSensingSystem::errorTolerance;
        }

        part matrix : SensingMatrix {
            attribute rows = CompressiveSensingSystem::measurementCount;
            attribute columns = CompressiveSensingSystem::systemDimension;
            attribute coherence = 0.1;
            attribute isRandomized = true;
        }

        part basis : SparseBasis {
            attribute basisType = "Wavelet";
            attribute dimension = CompressiveSensingSystem::systemDimension;
        }

        connect source.signalOut to encoder.signalIn;
        connect encoder.sparseOut to projector.sparseIn;
        connect projector.measurementsOut to solver.measurementsIn;
        connect solver.solutionOut to reconstructor.sparseCoefficientsIn;
        connect reconstructor.reconstructedOut to validator.reconstructedIn;
        connect source.signalOut to validator.originalIn;

        perform action sensing : PerformCompressiveSensing {
            in inputSignal;
            in targetMeasurements = CompressiveSensingSystem::measurementCount;
            in sparsityConstraint = CompressiveSensingSystem::expectedSparsity;
            in convergenceTol = CompressiveSensingSystem::errorTolerance;
            out outputSignal;
            out qualityMetric;
        }
    }

    requirement def CompressiveSensingCapability {
        doc /* 
            The system shall acquire and reconstruct signals using measurements 
            that are significantly fewer than the signal dimension, exploiting 
            sparsity to enable sub-Nyquist sampling.
        */

        subject system : CompressiveSensingSystem;

        require constraint measurementReduction {
            doc /* Measurement count shall be less than half the signal dimension. */
            system.measurementCount < system.systemDimension / 2
        }

        require constraint sparsityExploitation {
            doc /* Expected sparsity shall be much less than signal dimension. */
            system.expectedSparsity < system.systemDimension / 10
        }

        require constraint compressionEfficiency {
            doc /* Compression ratio shall achieve at least 4:1 reduction. */
            system.compressionRatio <= 0.25
        }
    }

    requirement def ReconstructionFidelityReq {
        doc /* 
            The reconstructed signal shall accurately represent the original 
            signal within specified error bounds.
        */

        subject system : CompressiveSensingSystem;

        require constraint errorBound {
            doc /* Reconstruction error shall be below tolerance threshold. */
            system.validator.errorThreshold < 0.05
        }

        require constraint convergenceGuarantee {
            doc /* L1 solver shall converge within maximum iterations. */
            system.solver.maxIterations >= 500
        }
    }

    requirement def MatrixIncoherenceReq {
        doc /* 
            The sensing matrix shall exhibit low coherence with the sparsity 
            basis to ensure reconstruction guarantees.
        */

        subject matrix : SensingMatrix;

        require constraint coherenceBound {
            doc /* Matrix coherence shall be below theoretical threshold. */
            matrix.coherence < 0.2
        }

        require constraint randomization {
            doc /* Sensing matrix shall use randomized construction. */
            matrix.isRandomized == true
        }
    }

    requirement <'CS-SYS-001'> compressiveSensingRequirement : CompressiveSensingCapability {
        doc /* 
            The compressive sensing system shall enable efficient signal acquisition 
            by exploiting sparsity to reduce required measurements below the Nyquist 
            rate while maintaining reconstruction quality through L1-norm optimization.
        */

        subject system = compressiveSensingSystem;

        assume constraint signalSparsity {
            doc /* Input signals are sparse in a known transform domain. */
            compressiveSensingSystem.source.targetSparsity <= 
            compressiveSensingSystem.expectedSparsity
        }

        assume constraint matrixProperties {
            doc /* Sensing matrix satisfies restricted isometry property. */
            compressiveSensingSystem.matrix.isRandomized and
            compressiveSensingSystem.matrix.coherence < 0.2
        }

        require reconstructionFidelityReq;
        require matrixIncoherenceReq;
    }

    requirement <'CS-SYS-002'> reconstructionAccuracy {
        doc /* 
            The system shall reconstruct signals with error below 1% of signal 
            amplitude range for signals meeting sparsity assumptions.
        */

        subject validator = compressiveSensingSystem.validator;

        require constraint errorMetric {
            validator.errorThreshold < 0.01
        }
    }

    requirement <'CS-SYS-003'> computationalEfficiency {
        doc /* 
            The reconstruction algorithm shall converge within bounded iterations 
            to ensure real-time processing capability.
        */

        subject solver = compressiveSensingSystem.solver;

        require constraint iterationBound {
            solver.maxIterations <= 1000
        }

        require constraint convergenceRate {
            solver.convergenceTolerance <= 0.01
        }
    }

    requirement reconstructionFidelityReq : ReconstructionFidelityReq {
        subject system = compressiveSensingSystem;
    }

    requirement matrixIncoherenceReq : MatrixIncoherenceReq {
        subject matrix = compressiveSensingSystem.matrix;
    }

    part compressiveSensingSystem : CompressiveSensingSystem {
        attribute systemDimension = 2048;
        attribute measurementCount = 512;
        attribute expectedSparsity = 100;
        attribute compressionRatio = 0.25;
        attribute errorTolerance = 0.005;
    }
}
