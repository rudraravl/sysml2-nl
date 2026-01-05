package SpeculumSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ReflectanceCoefficient :> Real;
	
	item def LightBeam {
		attribute wavelength :> LengthValue;
		attribute intensity :> PowerValue;
		attribute incidentAngle :> AngleValue;
		attribute polarization :> Real;
	}
	
	item def ReflectedBeam {
		attribute wavelength :> LengthValue;
		attribute intensity :> PowerValue;
		attribute reflectionAngle :> AngleValue;
		attribute polarization :> Real;
	}
	
	port def OpticalInputPort {
		in item incomingLight : LightBeam;
	}
	
	port def OpticalOutputPort {
		out item outgoingLight : ReflectedBeam;
	}
	
	part def ReflectiveSurface {
		attribute reflectivity :> ReflectanceCoefficient;
		attribute surfaceRoughness :> LengthValue;
		attribute coatingType : String;
		
		port inputPort : OpticalInputPort;
		port outputPort : OpticalOutputPort;
		
		action performReflection {
			in incident : LightBeam;
			out reflected : ReflectedBeam;
			
			constraint reflectionLaw {
				incident.incidentAngle == reflected.reflectionAngle
			}
		}
	}
	
	part def SubstrateBase {
		attribute material : String;
		attribute thickness :> LengthValue;
		attribute thermalExpansion :> Real;
	}
	
	part def OpticalCoating {
		attribute coatingMaterial : String;
		attribute coatingThickness :> LengthValue;
		attribute reflectanceValue :> ReflectanceCoefficient;
	}
	
	part def MountingAssembly {
		attribute mountType : String;
		attribute adjustability : Boolean;
		
		action secureMirror {
			in mirrorWeight :> MassValue;
			out stability : Real;
		}
	}
	
	action def CaptureIncomingLight {
		in lightSource : LightBeam;
		out capturedBeam : LightBeam;
	}
	
	action def ApplyReflectionPhysics {
		in surfaceCharacteristics : ReflectiveSurface;
		in incomingBeam : LightBeam;
		out reflectedBeam : ReflectedBeam;
		
		first start;
		then action calculateAngle {
			in angle : AngleValue = incomingBeam.incidentAngle;
			out resultAngle : AngleValue;
		}
		then action computeIntensity {
			in originalIntensity : PowerValue = incomingBeam.intensity;
			in reflectance : ReflectanceCoefficient = surfaceCharacteristics.reflectivity;
			out finalIntensity : PowerValue;
		}
		then assign reflectedBeam.reflectionAngle := calculateAngle.resultAngle;
		then assign reflectedBeam.intensity := computeIntensity.finalIntensity;
		then done;
	}
	
	action def DirectReflectedLight {
		in processedBeam : ReflectedBeam;
		out outputBeam : ReflectedBeam;
	}
	
	action def SpeculumReflectionOperation {
		in lightSource : LightBeam;
		in surfaceCharacteristics : ReflectiveSurface;
		out outputBeam : ReflectedBeam;
		
		first start;
		then action capture : CaptureIncomingLight {
			in lightSource = lightSource;
			out capturedBeam;
		}
		then action reflect : ApplyReflectionPhysics {
			in surfaceCharacteristics = surfaceCharacteristics;
			in incomingBeam = capture.capturedBeam;
			out reflectedBeam;
		}
		then action direct : DirectReflectedLight {
			in processedBeam = reflect.reflectedBeam;
			out outputBeam = outputBeam;
		}
		then done;
	}
	
	requirement def ReflectancePerformance {
		doc /* The speculum shall maintain minimum reflectance coefficient across operational wavelength range. */
		
		subject mirror : Speculum;
		
		require constraint minReflectance {
			mirror.primarySurface.reflectivity >= 0.92
		}
	}
	
	requirement def OpticalAccuracy {
		doc /* The reflected beam angle shall conform to the law of reflection within specified tolerance. */
		
		subject mirror : Speculum;
		
		require constraint angleTolerance {
			mirror.incidentBeam.incidentAngle == mirror.reflectedOutput.reflectionAngle
		}
	}
	
	requirement def SurfaceQuality {
		doc /* The reflective surface roughness shall not exceed maximum tolerance to ensure specular reflection. */
		
		subject surface : ReflectiveSurface;
		
		require constraint roughnessLimit {
			surface.surfaceRoughness <= 20.0
		}
	}
	
	requirement <'SPEC-REQ-001'> speculumSystemRequirements {
		doc /* The speculum system shall provide high-quality specular reflection for optical applications. */
		
		require reflectanceReq : ReflectancePerformance;
		require accuracyReq : OpticalAccuracy;
		require surfaceReq : SurfaceQuality;
	}
	
	part def Speculum {
		doc /* 
		A speculum is a precision optical instrument designed to reflect light through 
		specular reflection. Its primary function is to redirect incident light beams 
		according to the law of reflection, where the angle of incidence equals the 
		angle of reflection. The speculum consists of a highly polished reflective 
		surface, typically coated with metallic or dielectric materials, mounted on a 
		stable substrate. It operates by receiving incoming light at its optical input, 
		reflecting it off the mirror surface with minimal scattering or absorption, and 
		directing the reflected beam to its optical output. This enables applications 
		in imaging systems, telescopes, laser systems, and other optical instruments 
		requiring precise light path control.
		*/
		
		attribute overallReflectance :> ReflectanceCoefficient;
		attribute effectiveArea :> AreaValue;
		attribute systemMass :> MassValue;
		
		part primarySurface : ReflectiveSurface {
			attribute :>> reflectivity = 0.95;
			attribute :>> surfaceRoughness = 15.0;
			attribute :>> coatingType = "enhanced aluminum";
		}
		
		part substrate : SubstrateBase {
			attribute :>> material = "fused silica";
			attribute :>> thickness = 6.0;
			attribute :>> thermalExpansion = 0.55e-6;
		}
		
		part coating : OpticalCoating {
			attribute :>> coatingMaterial = "aluminum with SiO2 overcoat";
			attribute :>> coatingThickness = 120.0;
			attribute :>> reflectanceValue = 0.95;
		}
		
		part mounting : MountingAssembly {
			attribute :>> mountType = "kinematic";
			attribute :>> adjustability = true;
		}
		
		port opticalIn : OpticalInputPort;
		port opticalOut : OpticalOutputPort;
		
		connection inputPath connect opticalIn to primarySurface.inputPort;
		connection outputPath connect primarySurface.outputPort to opticalOut;
		
		attribute incidentBeam : LightBeam;
		attribute reflectedOutput : ReflectedBeam;
		
		perform action mainOperation : SpeculumReflectionOperation;
		
		state operationalStates {
			entry; then standby;
			
			state standby {
				entry assign overallReflectance := primarySurface.reflectivity;
			}
			
			state active {
				do action executeReflection : SpeculumReflectionOperation;
				
				state verifyingQuality {
					entry;
					then checkReflectance;
					
					state checkReflectance;
					
					state operational;
				}
			}
		}
	}
	
	part speculumInstrument : Speculum {
		attribute :>> overallReflectance = 0.95;
		attribute :>> effectiveArea = 0.01;
		attribute :>> systemMass = 0.3;
		
		satisfy speculumSystemRequirements;
	}
}
