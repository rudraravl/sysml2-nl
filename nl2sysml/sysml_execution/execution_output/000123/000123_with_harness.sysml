package 'Conditional Succession Example-2' {
	part def Scene;
	part def Image {
		isWellFocused: ScalarValues::Boolean;
	}
	part def Picture;
	
	action def Focus { in scene : Scene; out image : Image; }
	action def Shoot { in image: Image; out picture : Picture; }	
	action def TakePicture { in scene : Scene; out picture : Picture; }
	
	action takePicture : TakePicture {
		in item scene;
		out item picture;
		
		action focus : Focus {
			in item scene = takePicture::scene; 
			out item image;
		}
		
		if focus.image.isWellFocused then shoot;
		
		flow from focus.image to shoot.image;

		action shoot : Shoot {
			in item image; 
			out item picture = takePicture::picture;
		}
	}
	
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import 'Conditional Succession Example-2'::*;

    action orchestrator {
        action takePictureProbe : TakePicture {
            // TODO(human): unsupported input type for scene: Scene (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first takePictureProbe;
    }
}
