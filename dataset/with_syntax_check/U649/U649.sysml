package 'Diffusion Tensor Imaging System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MagneticFieldStrength :> ISQ::MagneticFluxDensityValue;
	attribute def GradientStrength :> ISQ::MagneticFluxDensityValue;
	attribute def BValue :> Real {
		doc /* Diffusion weighting factor in s/mm^2 */
	}
	attribute def DiffusionCoefficient :> Real {
		doc /* Apparent diffusion coefficient in mm^2/s */
	}
	attribute def FractionalAnisotropy :> Real {
		doc /* Measure of directional diffusion, range 0 to 1 */
	}
	
	attribute def GradientDirection {
		attribute gx : Real;
		attribute gy : Real;
		attribute gz : Real;
	}
	
	attribute def VoxelCoordinate {
		attribute x : ISQ::LengthValue;
		attribute y : ISQ::LengthValue;
		attribute z : ISQ::LengthValue;
	}
	
	attribute def DiffusionTensor {
		attribute dxx : DiffusionCoefficient;
		attribute dxy : DiffusionCoefficient;
		attribute dxz : DiffusionCoefficient;
		attribute dyy : DiffusionCoefficient;
		attribute dyz : DiffusionCoefficient;
		attribute dzz : DiffusionCoefficient;
	}
	
	item def RawKSpaceData {
		attribute dataPoints : Real;
		attribute gradientDirection : GradientDirection;
		attribute bValue : BValue;
	}
	
	item def DiffusionWeightedImage {
		attribute voxelIntensities : Real;
		attribute gradientDirection : GradientDirection;
		attribute bValue : BValue;
	}
	
	item def TensorField {
		attribute tensors : DiffusionTensor;
		attribute voxelPositions : VoxelCoordinate;
	}
	
	item def FiberTractMap {
		attribute tractPaths : VoxelCoordinate;
		attribute faValues : FractionalAnisotropy;
	}
	
	port def MagneticFieldPort {
		out fieldStrength : MagneticFieldStrength;
	}
	
	port def GradientPort {
		in gradientControl : GradientDirection;
		out gradientField : GradientStrength;
	}
	
	port def RFPort {
		out rfPulse : ISQ::PowerValue;
		in mrSignal : Real;
	}
	
	port def DataPort {
		out rawData : RawKSpaceData;
	}
	
	port def ImagePort {
		in rawData : RawKSpaceData;
		out image : DiffusionWeightedImage;
	}
	
	port def TensorPort {
		in images : DiffusionWeightedImage;
		out tensorField : TensorField;
	}
	
	port def TractographyPort {
		in tensorField : TensorField;
		out fiberTracts : FiberTractMap;
	}
	
	part def MainMagnet {
		attribute fieldStrength : MagneticFieldStrength;
		port magneticField : MagneticFieldPort;
	}
	
	part def GradientCoilSystem {
		attribute maxGradientStrength : GradientStrength;
		port gradientOutput : GradientPort;
	}
	
	part def RFTransceiver {
		port rfInterface : RFPort;
	}
	
	part def DataAcquisitionUnit {
		port signalInput : RFPort;
		port dataOutput : DataPort;
	}
	
	part def ImageReconstructionUnit {
		port imageInput : ImagePort;
	}
	
	part def TensorComputationEngine {
		port tensorInput : TensorPort;
	}
	
	part def TractographyEngine {
		port tractInput : TractographyPort;
	}
	
	part def PatientTable {
		attribute position : ISQ::LengthValue;
	}
	
	action def ApplyGradientPulse {
		in direction : GradientDirection;
		in strength : GradientStrength;
		in duration : ISQ::TimeValue;
		out appliedGradient : GradientStrength;
	}
	
	action def TransmitRFPulse {
		in frequency : ISQ::FrequencyValue;
		in flipAngle : Real;
		in duration : ISQ::TimeValue;
		out excitation : Real;
	}
	
	action def AcquireMRSignal {
		in echoTime : ISQ::TimeValue;
		out signalData : Real;
	}
	
	action def ReconstructDWImage {
		in kSpaceData : RawKSpaceData;
		out dwImage : DiffusionWeightedImage;
	}
	
	action def ComputeTensorField {
		in dwImages : DiffusionWeightedImage;
		in gradientScheme : GradientDirection;
		in bValues : BValue;
		out tensorField : TensorField;
	}
	
	action def CalculateFractionalAnisotropy {
		in tensor : DiffusionTensor;
		out fa : FractionalAnisotropy;
	}
	
	action def GenerateFiberTracts {
		in tensorField : TensorField;
		in seedPoints : VoxelCoordinate;
		in faThreshold : FractionalAnisotropy;
		in stepSize : ISQ::LengthValue;
		out tracts : FiberTractMap;
	}
	
	action def AcquireDiffusionWeightedVolume {
		in gradientDirection : GradientDirection;
		in bValue : BValue;
		in repetitionTime : ISQ::TimeValue;
		in echoTime : ISQ::TimeValue;
		out dwImage : DiffusionWeightedImage;
		
		first start;
		then action applyGradient : ApplyGradientPulse {
			in direction = gradientDirection;
			in strength;
			in duration;
			out appliedGradient;
		}
		then action transmitPulse : TransmitRFPulse {
			in frequency;
			in flipAngle;
			in duration;
			out excitation;
		}
		then action acquireSignal : AcquireMRSignal {
			in echoTime = AcquireDiffusionWeightedVolume::echoTime;
			out signalData;
		}
		then action reconstruct : ReconstructDWImage {
			in kSpaceData;
			out dwImage;
		}
		then done;
	}
	
	action def PerformDTIScan {
		in numberOfDirections : Integer;
		in bValueSettings : BValue;
		in repetitionTime : ISQ::TimeValue;
		in echoTime : ISQ::TimeValue;
		in gradientScheme : GradientDirection;
		out tensorField : TensorField;
		out fiberTracts : FiberTractMap;
		
		first start;
		then action acquireVolume : AcquireDiffusionWeightedVolume {
			in gradientDirection = gradientScheme;
			in bValue = bValueSettings;
			in repetitionTime = PerformDTIScan::repetitionTime;
			in echoTime = PerformDTIScan::echoTime;
			out dwImage;
		}
		then action computeTensors : ComputeTensorField {
			in dwImages = acquireVolume.dwImage;
			in gradientScheme = PerformDTIScan::gradientScheme;
			in bValues = bValueSettings;
			out tensorField;
		}
		then action calculateFA : CalculateFractionalAnisotropy {
			in tensor = computeTensors.tensorField.tensors;
			out fa;
		}
		then action generateTracts : GenerateFiberTracts {
			in tensorField = computeTensors.tensorField;
			in seedPoints;
			in faThreshold = calculateFA.fa;
			in stepSize;
			out tracts;
		}
		then assign fiberTracts := generateTracts.tracts;
		then done;
	}
	
	state def DTISystemStates {
		entry; then idle;
		
		state idle {
			doc /* System ready, awaiting scan initiation */
		}
		
		state calibrating {
			doc /* Performing system calibration and shimming */
		}
		
		state positioning {
			doc /* Positioning patient and preparing scan */
		}
		
		state acquiring {
			doc /* Acquiring diffusion-weighted volumes */
		}
		
		state reconstructing {
			doc /* Reconstructing images from k-space data */
		}
		
		state computing {
			doc /* Computing diffusion tensors and metrics */
		}
		
		state tractography {
			doc /* Generating fiber tract maps */
		}
		
		state complete {
			doc /* Scan complete, results available */
		}
		
		transition idle to calibrating;
		transition calibrating to positioning;
		transition positioning to acquiring;
		transition acquiring to reconstructing;
		transition reconstructing to computing;
		transition computing to tractography;
		transition tractography to complete;
		transition complete to idle;
	}
	
	part dtiSystem {
		doc /* Complete diffusion tensor imaging system for mapping white matter fiber architecture in brain tissue */
		
		part magnet : MainMagnet {
			attribute fieldStrength = 3.0;
		}
		
		part gradientSystem : GradientCoilSystem {
			attribute maxGradientStrength = 80.0;
		}
		
		part rfSystem : RFTransceiver;
		
		part dataAcquisition : DataAcquisitionUnit;
		
		part imageReconstruction : ImageReconstructionUnit;
		
		part tensorComputation : TensorComputationEngine;
		
		part tractography : TractographyEngine;
		
		part table : PatientTable;
		
		connect magnet.magneticField to gradientSystem.gradientOutput;
		connect rfSystem.rfInterface to dataAcquisition.signalInput;
		connect dataAcquisition.dataOutput to imageReconstruction.imageInput;
		connect imageReconstruction.imageInput to tensorComputation.tensorInput;
		connect tensorComputation.tensorInput to tractography.tractInput;
		
		perform action dtiImaging : PerformDTIScan {
			in numberOfDirections = 64;
			in bValueSettings;
			in repetitionTime = 8000.0;
			in echoTime = 90.0;
			in gradientScheme;
			out tensorField;
			out fiberTracts;
		}
		
		exhibit state systemStates : DTISystemStates;
	}
	
	requirement def PrimaryFunction {
		doc /* Primary functional requirement for DTI system */
	}
	
	requirement <'DTI-FUNC-001'> mapWhiteMatterConnectivity : PrimaryFunction {
		doc /* The DTI system shall non-invasively map and visualize the three-dimensional architecture 
		     of white matter fiber tracts in brain tissue by measuring the directional diffusion of water 
		     molecules along axonal pathways, computing diffusion tensors at each voxel, and reconstructing 
		     continuous fiber trajectories through tractography algorithms. */
		
		require constraint {
			doc /* System shall acquire diffusion-weighted images along at least 6 non-collinear gradient directions */
		}
		
		require constraint {
			doc /* System shall compute full 3x3 symmetric diffusion tensor at each voxel */
		}
		
		require constraint {
			doc /* System shall generate fractional anisotropy maps with values between 0 and 1 */
		}
		
		require constraint {
			doc /* System shall reconstruct fiber tracts using tensor principal eigenvector integration */
		}
	}
	
	requirement <'DTI-PERF-001'> imagingPerformance {
		doc /* The system shall provide sufficient spatial resolution and signal quality to resolve 
		     major white matter tracts in the human brain. */
		
		require constraint {
			doc /* Voxel size shall be 2mm isotropic or finer */
		}
		
		require constraint {
			doc /* Minimum 30 gradient directions for robust tensor estimation */
		}
		
		require constraint {
			doc /* Signal-to-noise ratio shall exceed 20:1 in baseline images */
		}
	}
	
	requirement <'DTI-TRACT-001'> tractographyCapability {
		doc /* The tractography engine shall reconstruct anatomically plausible fiber pathways. */
		
		require constraint {
			doc /* Tractography shall terminate when FA falls below configurable threshold */
		}
		
		require constraint {
			doc /* Maximum tract curvature shall be limited to prevent anatomically implausible paths */
		}
		
		require constraint {
			doc /* System shall support both deterministic and probabilistic tractography methods */
		}
	}
	
	requirement primaryMission {
		doc /* Primary mission: Characterize brain white matter microstructure and connectivity by 
		     measuring anisotropic water diffusion to enable clinical diagnosis of neurological 
		     disorders and neuroscience research into structural brain networks. */
		
		assume constraint {
			doc /* Water diffusion in white matter is anisotropic along myelinated axon bundles */
		}
		
		assume constraint {
			doc /* Diffusion tensor model adequately represents tissue microstructure in white matter */
		}
		
		require mapWhiteMatterConnectivity;
		require imagingPerformance;
		require tractographyCapability;
	}
}
