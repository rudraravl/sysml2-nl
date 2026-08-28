package 'Compressive Sensing System' {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    
    doc /* This model describes a compressive sensing system for efficient signal acquisition and reconstruction. */
    
    attribute def SignalValue :> Real {
        doc /* A scalar sample value of a signal, in arbitrary units. */
    }
    attribute def SparseCoefficientValue :> Real {
        doc /* A coefficient value in a sparse representation. */
    }
    attribute def MeasurementValue :> Real {
        doc /* A single compressive measurement value. */
    }
    attribute def ErrorMetric :> Real {
        doc /* Reconstruction error metric, e.g., root mean square error. */
    }
    attribute def CompressionRatio :> Real {
        doc /* Ratio of original signal size to compressed measurement size. */
    }
    
    item def OriginalSignal {
        doc /* The original high-resolution signal to be acquired and reconstructed. */
        attribute samples : SignalValue[0..*] ordered;
    }
    item def SparseSignal {
        doc /* The signal represented in a sparse basis with few significant coefficients. */
        attribute coefficients : SparseCoefficientValue[0..*] ordered;
    }
    item def CompressedMeasurements {
        doc /* A reduced set of linear measurements obtained through random projection. */
        attribute values : MeasurementValue[0..*] ordered;
    }
    item def ReconstructedSignal :> OriginalSignal {
        doc /* The reconstructed signal after inverse transformation. */
    }
    item def SparseBasis {
        doc /* The basis used for sparse representation, e.g., a Wavelet basis. */
        attribute entries : Real[0..*] ordered;
    }
    item def SensingMatrix {
        doc /* A random-like matrix used to project the sparse signal to fewer measurements. */
        attribute entries : Real[0..*] ordered;
    }
    item def QualityReport {
        doc /* Report containing quality metrics comparing original and reconstructed signals. */
        attribute reconstructionError : ErrorMetric;
        attribute compressionRatio : CompressionRatio;
    }
    
    action def GenerateSignal {
        doc /* Generates the original high-resolution signal. */
        out originalSignal : OriginalSignal;
    }
    action def SparseEncode {
        doc /* Transforms the original signal into its sparse representation using a sparse basis. */
        in originalSignal : OriginalSignal;
        in basis : SparseBasis;
        out sparseSignal : SparseSignal;
    }
    action def RandomProject {
        doc /* Projects the sparse signal into a low-dimensional measurement vector using a sensing matrix. */
        in sparseSignal : SparseSignal;
        in sensingMatrix : SensingMatrix;
        out measurements : CompressedMeasurements;
    }
    action def SolveL1 {
        doc /* Solves an L1 minimization to recover the sparse coefficient vector from measurements. */
        in measurements : CompressedMeasurements;
        in sensingMatrix : SensingMatrix;
        in basis : SparseBasis;
        out sparseRecovered : SparseSignal;
    }
    action def ReconstructSignal {
        doc /* Reconstructs the signal from the recovered sparse coefficients using the inverse sparse basis. */
        in sparseRecovered : SparseSignal;
        in basis : SparseBasis;
        out reconstructedSignal : ReconstructedSignal;
    }
    action def ValidateQuality {
        doc /* Compares original and reconstructed signals to compute reconstruction error and compression ratio. */
        in originalSignal : OriginalSignal;
        in reconstructedSignal : ReconstructedSignal;
        out qualityReport : QualityReport;
    }
    action def CompressiveSensingProcess {
        doc /* Top-level action representing the complete compressive sensing workflow. */
        in basis : SparseBasis;
        in sensingMatrix : SensingMatrix;
        out reconstructedSignal : ReconstructedSignal;
        out qualityReport : QualityReport;
    }
    
    part def SignalSource {
        doc /* Component that generates the original high-resolution signal. */
        port originalSignalPort {
            out originalSignal : OriginalSignal;
        }
        action generate : GenerateSignal {
            out originalSignal = originalSignalPort.originalSignal;
        }
    }
    part def SparseEncoder {
        doc /* Component that transforms the original signal into a sparse representation. */
        port originalSignalPort {
            in originalSignal : OriginalSignal;
        }
        port basisPort {
            in basis : SparseBasis;
        }
        port sparseSignalPort {
            out sparseSignal : SparseSignal;
        }
        action encode : SparseEncode {
            in originalSignal = originalSignalPort.originalSignal;
            in basis = basisPort.basis;
            out sparseSignal = sparseSignalPort.sparseSignal;
        }
    }
    part def RandomProjector {
        doc /* Component that performs compressive random projection. */
        port sparseSignalPort {
            in sparseSignal : SparseSignal;
        }
        port sensingMatrixPort {
            in sensingMatrix : SensingMatrix;
        }
        port measurementsPort {
            out measurements : CompressedMeasurements;
        }
        action project : RandomProject {
            in sparseSignal = sparseSignalPort.sparseSignal;
            in sensingMatrix = sensingMatrixPort.sensingMatrix;
            out measurements = measurementsPort.measurements;
        }
    }
    part def L1Solver {
        doc /* Component that solves the L1 optimization to recover sparse coefficients. */
        port measurementsPort {
            in measurements : CompressedMeasurements;
        }
        port sensingMatrixPort {
            in sensingMatrix : SensingMatrix;
        }
        port basisPort {
            in basis : SparseBasis;
        }
        port sparseRecoveredPort {
            out sparseRecovered : SparseSignal;
        }
        action solve : SolveL1 {
            in measurements = measurementsPort.measurements;
            in sensingMatrix = sensingMatrixPort.sensingMatrix;
            in basis = basisPort.basis;
            out sparseRecovered = sparseRecoveredPort.sparseRecovered;
        }
    }
    part def SignalReconstructor {
        doc /* Component that reconstructs the original-format signal from sparse coefficients. */
        port sparseRecoveredPort {
            in sparseRecovered : SparseSignal;
        }
        port basisPort {
            in basis : SparseBasis;
        }
        port reconstructedSignalPort {
            out reconstructedSignal : ReconstructedSignal;
        }
        action reconstruct : ReconstructSignal {
            in sparseRecovered = sparseRecoveredPort.sparseRecovered;
            in basis = basisPort.basis;
            out reconstructedSignal = reconstructedSignalPort.reconstructedSignal;
        }
    }
    part def QualityValidator {
        doc /* Component that compares original and reconstructed signals to produce a quality report. */
        port originalSignalPort {
            in originalSignal : OriginalSignal;
        }
        port reconstructedSignalPort {
            in reconstructedSignal : ReconstructedSignal;
        }
        port qualityReportPort {
            out qualityReport : QualityReport;
        }
        action validate : ValidateQuality {
            in originalSignal = originalSignalPort.originalSignal;
            in reconstructedSignal = reconstructedSignalPort.reconstructedSignal;
            out qualityReport = qualityReportPort.qualityReport;
        }
    }
    
    part def CompressiveSensingSystem {
        doc /* Top-level system composed of compressive sensing components. */
        part signalSource : SignalSource;
        part sparseEncoder : SparseEncoder;
        part randomProjector : RandomProjector;
        part l1Solver : L1Solver;
        part signalReconstructor : SignalReconstructor;
        part qualityValidator : QualityValidator;
        
        port basisPort {
            in basis : SparseBasis;
        }
        port sensingMatrixPort {
            in sensingMatrix : SensingMatrix;
        }
        port reconstructedSignalPort {
            out reconstructedSignal : ReconstructedSignal;
        }
        port qualityReportPort {
            out qualityReport : QualityReport;
        }
        
        connect signalSource.originalSignalPort to sparseEncoder.originalSignalPort;
        connect sparseEncoder.sparseSignalPort to randomProjector.sparseSignalPort;
        connect randomProjector.measurementsPort to l1Solver.measurementsPort;
        connect l1Solver.sparseRecoveredPort to signalReconstructor.sparseRecoveredPort;
        connect signalSource.originalSignalPort to qualityValidator.originalSignalPort;
        connect signalReconstructor.reconstructedSignalPort to qualityValidator.reconstructedSignalPort;
        
        connect basisPort to sparseEncoder.basisPort;
        connect basisPort to l1Solver.basisPort;
        connect basisPort to signalReconstructor.basisPort;
        connect sensingMatrixPort to randomProjector.sensingMatrixPort;
        connect sensingMatrixPort to l1Solver.sensingMatrixPort;
        
        connect signalReconstructor.reconstructedSignalPort to reconstructedSignalPort;
        connect qualityValidator.qualityReportPort to qualityReportPort;
    }
    
    action compressiveSensing : CompressiveSensingProcess {
        doc /* Functional action usage showing the sequential compressive sensing workflow. */
        in item basis;
        in item sensingMatrix;
        out item reconstructedSignal;
        out item qualityReport;
        
        action generate : GenerateSignal {
            out item originalSignal;
        }
        action encode : SparseEncode {
            in item originalSignal;
            in item basis = compressiveSensing::basis;
            out item sparseSignal;
        }
        flow from generate.originalSignal to encode.originalSignal;
        
        action project : RandomProject {
            in item sparseSignal;
            in item sensingMatrix = compressiveSensing::sensingMatrix;
            out item measurements;
        }
        flow from encode.sparseSignal to project.sparseSignal;
        
        action solve : SolveL1 {
            in item measurements;
            in item sensingMatrix = compressiveSensing::sensingMatrix;
            in item basis = compressiveSensing::basis;
            out item sparseRecovered;
        }
        flow from project.measurements to solve.measurements;
        
        action reconstruct : ReconstructSignal {
            in item sparseRecovered;
            in item basis = compressiveSensing::basis;
            out item reconstructedSignal = compressiveSensing::reconstructedSignal;
        }
        flow from solve.sparseRecovered to reconstruct.sparseRecovered;
        
        action validate : ValidateQuality {
            in item originalSignal = generate.originalSignal;
            in item reconstructedSignal;
            out item qualityReport = compressiveSensing::qualityReport;
        }
        flow from reconstruct.reconstructedSignal to validate.reconstructedSignal;
        
        first start;
        then action generate;
        then action encode;
        then action project;
        then action solve;
        then action reconstruct;
        then action validate;
        then done;
    }
}
