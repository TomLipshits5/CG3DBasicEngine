#include "Assignment2.h"
#include <iostream>


static void printMat(const Eigen::Matrix4d& mat)
{
	std::cout<<" matrix:"<<std::endl;
	for (int i = 0; i < 4; i++)
	{
		for (int j = 0; j < 4; j++)
			std::cout<< mat(j,i)<<" ";
		std::cout<<std::endl;
	}
}

Assignment2::Assignment2()
{
	SceneParser("/home/tomcooll/Desktop/Personal/Computer Science/Semester_D/Computer_Graphics_Engine/tutorial/Assignment2/scene1.txt", &scnData);
}

void Assignment2::Init()
{		
	unsigned int texIDs[3] = { 0 , 1, 2};
	unsigned int slots[3] = { 0 , 1, 2 };
	
	AddShader("shaders/pickingShader");
	AddShader("shaders/SIT2Shader");

	AddTexture("textures/box0.bmp",2);
	AddTexture("textures/grass.bmp", 2);

	AddMaterial(texIDs,slots, 1);
	AddMaterial(texIDs+1, slots+1, 1);

	AddShape(Plane, -1, TRIANGLES);

	SetShapeShader(0, 1);
	SetShapeMaterial(0, 1);

	SetShapeStatic(0);
}

void Assignment2::Update(const Eigen::Matrix4f& Proj, const Eigen::Matrix4f& View, const Eigen::Matrix4f& Model, unsigned int  shaderIndx, unsigned int shapeIndx)
{
	Shader *s = shaders[shaderIndx];
	int r = ((shapeIndx+1) & 0x000000FF) >>  0;
	int g = ((shapeIndx+1) & 0x0000FF00) >>  8;
	int b = ((shapeIndx+1) & 0x00FF0000) >> 16;	

	s->Bind();
	s->SetUniformMat4f("Proj", Proj);
	s->SetUniformMat4f("View", View);
	s->SetUniformMat4f("Model", Model);
	
	if (data_list[shapeIndx]->GetMaterial() >= 0 && !materials.empty())
	{
//		materials[shapes[pickedShape]->GetMaterial()]->Bind(textures);
		BindMaterial(s, data_list[shapeIndx]->GetMaterial());
	}
	if (shaderIndx == 0)
		s->SetUniform4f("lightColor", r / 255.0f, g / 255.0f, b / 255.0f, 0.0f);
	else {
        pixelSize = getPixelSize(800, 800);
        s->SetUniform4f("pixelSize", pixelSize[0], pixelSize[1], pixelSize[2], pixelSize[3]);
		s->SetUniform4f("lightColor", 4 / 100.0f, 60 / 100.0f, 99 / 100.0f, 0.5f);
		s->SetUniform4f("eye", scnData.eye[0], scnData.eye[1], scnData.eye[2], scnData.eye[3]);
		s->SetUniform4f("ambient", scnData.ambient[0], scnData.ambient[1], scnData.ambient[2], scnData.ambient[3]);
		s->SetUniform4fv("objects", &scnData.objects[0], scnData.objects.size());
		s->SetUniform4fv("objColors", &scnData.colors[0], scnData.colors.size());
		s->SetUniform4fv("lightsDirection", &scnData.directions[0], scnData.directions.size());
		s->SetUniform4fv("lightsIntensity", &scnData.intensities[0], scnData.intensities.size());
		s->SetUniform4fv("lightsPosition", &scnData.lights[0], scnData.lights.size());
		s->SetUniform4i("sizes", scnData.sizes[0], scnData.sizes[1], scnData.sizes[2], scnData.sizes[3]);
	}
	s->Unbind();
}

Eigen::Vector4f Assignment2::getPixelSize( const float display_width, const float display_height) const {
    float width_of_each_pixel = (1.0 /display_width) * (1.0 / zoom); // 1200 is the Width of the current window
    float height_of_each_pixel = (1.0/display_height) * (1.0 / zoom);
    return {height_of_each_pixel, width_of_each_pixel, 0, 0};
}


void Assignment2::WhenRotate(bool offset, bool xAxis)
{
	if (xAxis) {
		if (offset)
			move[0] += 0.1f;
		else
			move[1] -= 0.1f;

	}
	else {
		if (offset)
			move[1] += 0.1f;
		else
			move[0] -= 0.1f;

	}
}

void Assignment2::ZoomInOrOut(bool offset) {
	if (offset)
		zoom += 0.1;
	else if (!offset && zoom > 0.4)
		zoom -= 0.1;
	float width_of_each_pixel = (1.0 / 1200.0) * (1.0 / zoom); // 1200 is the Width of the current window
	std::cout << "Width of pixel is:  " << width_of_each_pixel << " ,Original width is: " << (1.0 / 1200.0) << std::endl;
}

void Assignment2::WhenTranslate()
{
}

void Assignment2::Animate() {
    if(isActive)
	{
		
	}
}

void Assignment2::ScaleAllShapes(float amt,int viewportIndx)
{
	for (int i = 1; i < data_list.size(); i++)
	{
		if (data_list[i]->Is2Render(viewportIndx))
		{
            data_list[i]->MyScale(Eigen::Vector3d(amt, amt, amt));
		}
	}
}

void Assignment2::MoveHorizontal(float xpos) {
	if (xpos > x) {
		move[0] += 0.01;
	}
	else if (xpos < x) {
		move[0] -= 0.01;
	}
	x = xpos;

}

void Assignment2::MoveVertical(float ypos) {
	if (ypos > y) {
		move[1] += 0.01;
	}
	else if (ypos < y) {
		move[1] -= 0.01;
	}
	y = ypos;
}


Assignment2::~Assignment2(void)
{
}

