package 'Ring Laser Gyroscope System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def LaserFrequency :> ISQ::FrequencyValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit;
	}
	
	attribute def BeatFrequency :> ISQ::FrequencyValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit;
	}
	
	attribute def AngularVelocity :> ISQ::AngularVelocityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngularVelocityUnit;
	}
	
	attribute def PathLength :> ISQ::LengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : LengthUnit;
	}
	
	attribute def Wavelength :> ISQ::LengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : LengthUnit;
	}
	
	attribute def OpticalPower :> ISQ::PowerValue {
		attribute :>> num : Real;
		attribute :>> mRef : PowerUnit;
	}
	
	attribute def Voltage :> Real;
	
	attribute def Current :> ISQ::ElectricCurrentValue {
		attribute :>> num : Real;
		attribute :>> mRef : ElectricCurrentUnit;
	}
	
	item def OpticalBeam {
		attribute power : OpticalPower;
		attribute wavelength : Wavelength;
		attribute frequency : LaserFrequency;
	}
	
	item def ElectricalSignal {
		attribute voltage : Voltage;
		attribute current : Current;
	}
	
	item def RotationData {
		attribute angularRate : AngularVelocity;
		attribute timestamp : ISQ::TimeValue;
	}
	
	port def OpticalPort {
		out beam : OpticalBeam;
	}
	
	port def OpticalInputPort {
		in beam : OpticalBeam;
	}
	
	port def ElectricalPort {
		out signal : ElectricalSignal;
	}
	
	port def DataOutputPort {
		out rotationData : RotationData;
	}
	
	part def LaserGainMedium {
		port opticalOut : OpticalPort;
		attribute activeGas : String;
		attribute excitationVoltage : Voltage;
		attribute outputPower : OpticalPower;
		
		action generateLaserLight {
			in excitation : Voltage;
			out laserBeam : OpticalBeam;
		}
	}
	
	part def Mirror {
		port opticalIn : OpticalInputPort;
		port opticalOut : OpticalPort;
		attribute reflectivity : Real;
		attribute position : PathLength;
		
		action reflectBeam {
			in incidentBeam : OpticalBeam;
			out reflectedBeam : OpticalBeam;
		}
	}
	
	part def BeamSplitter {
		port opticalIn : OpticalInputPort;
		port opticalOut1 : OpticalPort;
		port opticalOut2 : OpticalPort;
		attribute splitRatio : Real;
		
		action splitBeam {
			in inputBeam : OpticalBeam;
			out clockwiseBeam : OpticalBeam;
			out counterClockwiseBeam : OpticalBeam;
		}
	}
	
	part def Photodetector {
		port opticalIn1 : OpticalInputPort;
		port opticalIn2 : OpticalInputPort;
		port electricalOut : ElectricalPort;
		attribute sensitivity : Real;
		attribute responsivity : Real;
		
		action detectInterference {
			in beam1 : OpticalBeam;
			in beam2 : OpticalBeam;
			out beatSignal : ElectricalSignal;
		}
	}
	
	part def SignalProcessor {
		port electricalIn : ElectricalPort;
		port dataOut : DataOutputPort;
		attribute scaleFactor : Real;
		attribute perimeter : PathLength;
		attribute wavelength : Wavelength;
		
		action computeRotationRate {
			in beatFrequencySignal : ElectricalSignal;
			in gyroPerimeter : PathLength;
			in laserWavelength : Wavelength;
			out rotationRate : AngularVelocity;
		}
		
		action formatOutput {
			in rotationRate : AngularVelocity;
			out data : RotationData;
		}
	}
	
	part def RingCavity {
		part mirror1 : Mirror;
		part mirror2 : Mirror;
		part mirror3 : Mirror;
		part mirror4 : Mirror;
		attribute cavityPerimeter : PathLength;
		attribute areaEnclosed : ISQ::AreaValue;
		
		connection c1 connect mirror1.opticalOut to mirror2.opticalIn;
		connection c2 connect mirror2.opticalOut to mirror3.opticalIn;
		connection c3 connect mirror3.opticalOut to mirror4.opticalIn;
		connection c4 connect mirror4.opticalOut to mirror1.opticalIn;
	}
	
	action def MeasureRotation {
		in physicalRotation : AngularVelocity;
		out measuredRotation : AngularVelocity;
	}
	
	action def SagnacEffect {
		in rotationRate : AngularVelocity;
		in cavityPerimeter : PathLength;
		in cavityArea : ISQ::AreaValue;
		in wavelength : Wavelength;
		out beatFrequency : BeatFrequency;
	}
	
	part def RingLaserGyroscope {
		port rotationOutput : DataOutputPort;
		
		attribute operatingState : String;
		attribute lockStatus : Boolean;
		
		part gainMedium : LaserGainMedium {
			attribute :>> activeGas = "Helium-Neon";
		}
		
		part cavity : RingCavity;
		
		part beamCombiner : BeamSplitter;
		
		part detector : Photodetector;
		
		part processor : SignalProcessor;
		
		connection opticalPath1 connect gainMedium.opticalOut to cavity.mirror1.opticalIn;
		connection opticalPath2 connect cavity.mirror2.opticalOut to beamCombiner.opticalIn;
		connection cwBeam connect beamCombiner.opticalOut1 to detector.opticalIn1;
		connection ccwBeam connect beamCombiner.opticalOut2 to detector.opticalIn2;
		connection electricalPath connect detector.electricalOut to processor.electricalIn;
		connection outputPath connect processor.dataOut to rotationOutput;
		
		perform action measureRotation : MeasureRotation {
			out measuredRotation;
			
			first start;
			then action exciteLaser {
				action excite : LaserGainMedium::generateLaserLight {
					in excitation = gainMedium.excitationVoltage;
					out laserBeam;
				}
			}
			then action propagateBeams {
				action sagnac : SagnacEffect {
					in rotationRate;
					in cavityPerimeter = cavity.cavityPerimeter;
					in cavityArea = cavity.areaEnclosed;
					in wavelength = processor.wavelength;
					out beatFrequency;
				}
			}
			then action detectInterference {
				action detect : Photodetector::detectInterference {
					out beatSignal;
				}
			}
			then action processSignal {
				action compute : SignalProcessor::computeRotationRate {
					in beatFrequencySignal = detectInterference.detect.beatSignal;
					in gyroPerimeter = cavity.cavityPerimeter;
					in laserWavelength = processor.wavelength;
					out rotationRate;
				}
			}
			then action formatData {
				action format : SignalProcessor::formatOutput {
					in rotationRate = processSignal.compute.rotationRate;
					out data;
				}
			}
			then assign measuredRotation := formatData.format.data.angularRate;
			then done;
		}
		
		state def RLGOperationalStates {
			entry; then Standby;
			
			state Standby {
				entry assign RingLaserGyroscope::operatingState := "Standby";
				entry assign RingLaserGyroscope::lockStatus := false;
			}
			
			state Warmup {
				entry assign RingLaserGyroscope::operatingState := "Warmup";
			}
			
			state Locking {
				entry assign RingLaserGyroscope::operatingState := "Locking";
			}
			
			state Operating {
				entry assign RingLaserGyroscope::operatingState := "Operating";
				entry assign RingLaserGyroscope::lockStatus := true;
				do RingLaserGyroscope::measureRotation;
			}
			
			state Fault {
				entry assign RingLaserGyroscope::operatingState := "Fault";
				entry assign RingLaserGyroscope::lockStatus := false;
			}
			
			transition powerOn first Standby then Warmup;
			transition warmupComplete first Warmup then Locking;
			transition lockAcquired first Locking then Operating;
			transition lockLost first Operating then Locking;
			transition shutdown first Operating then Standby;
		}
	}
	
	requirement def RotationMeasurementRequirement {
		doc /* The ring laser gyroscope shall accurately measure angular rotation rate 
		       based on the Sagnac effect by detecting the beat frequency between 
		       counter-propagating laser beams in a closed optical path. */
		
		subject gyroscope : RingLaserGyroscope;
		
		require constraint sagnacPrinciple {
			doc /* The beat frequency shall be proportional to the rotation rate 
			       according to the Sagnac effect formula. */
		}
		
		require constraint continuousOperation {
			doc /* The gyroscope shall operate continuously to provide real-time 
			       rotation measurements. */
		}
	}
	
	requirement <'RLG-001'> gyroscopePerformance : RotationMeasurementRequirement {
		assume constraint opticalPathClosed {
			doc /* The ring cavity forms a closed optical path with counter-propagating beams. */
		}
		
		assume constraint laserCoherence {
			doc /* The laser gain medium produces coherent light suitable for interference detection. */
		}
	}
	
	requirement <'RLG-002'> measurementAccuracy {
		doc /* The gyroscope shall measure angular velocity with accuracy better than 0.01 deg/hr. */
		subject gyroscope : RingLaserGyroscope;
	}
	
	requirement <'RLG-003'> operationalStability {
		doc /* The gyroscope shall maintain frequency lock during normal operation. */
		subject gyroscope : RingLaserGyroscope;
		
		require constraint lockMaintained {
			gyroscope.lockStatus == true
		}
	}
	
	part ringLaserGyroscopeSystem : RingLaserGyroscope {
		satisfy gyroscopePerformance by ringLaserGyroscopeSystem;
		satisfy measurementAccuracy by ringLaserGyroscopeSystem;
		satisfy operationalStability by ringLaserGyroscopeSystem;
	}
}
