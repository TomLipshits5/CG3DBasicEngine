#version 330

uniform vec4 eye;
uniform vec4 ambient;
uniform vec4[20] objects;
uniform vec4[20] objColors;
uniform vec4[10] lightsDirection;
uniform vec4[10] lightsIntensity;
uniform vec4[10] lightsPosition;
uniform ivec4 sizes;
uniform vec4 pixelSize;

uniform vec4 move;
uniform float zoom;

in vec3 position0;
in vec3 normal0;


//quries:
bool isPlane(vec4 object){
    return object[3] <= 0;
}

bool isSphere(vec4 object){
    return object[3] > 0;
}

bool isSpotlight(vec4 light){
    return light[3] == 1.0;
}

bool isPointlight(vec4 light){
    return light[3] > 1.0;
}


//helper methods:
vec3 getObjectNormal(int objectIndex, vec3 sourcePoint){
    if(isPlane(objects[objectIndex])){
        return normalize(objects[objectIndex].xyz);
    }
    vec4 sphere = objects[objectIndex];
    return -normalize( sourcePoint - objects[objectIndex].xyz);
}


vec3 findPointOnPlane(vec4 plane){
    if(plane[0] != 0){
        return vec3(-plane[3]/plane[0], 0, 0);
    }else if(plane[1] != 0){
        return vec3(0, -plane[3]/plane[1], 0);
    }
    return vec3(0, 0, -plane[3]/plane[2]);
}


//Find intersections
float calulateSphereIntersection(vec4 sphere, vec3 sourcePoint, vec3 v){
    float t;
    vec3 sphereCenter = sphere.xyz;
    vec3 L = sphereCenter - sourcePoint;
    float tm = dot(L,v);
    float d = sqrt(dot(L,L) - tm*tm);
    float r = sphere[3];
    if(d > r){
        return -1.0;
    }
    if(tm >= 0){
        t = tm - sqrt(r*r - d*d);
    }else{
        t = tm + sqrt(r*r - d*d);
    }
    return t;
}

float calulatePlaneIntersection(vec4 plane, vec3 sourcePoint, vec3 v){
    vec3 n = normalize(plane.xyz);
    vec3 p0o = -plane.w*n/length(plane.xyz) - sourcePoint;
    float t = dot(n,p0o)/dot(n,v);
    if(t < 0){
        return -1.0;
    }
    return t;
}


vec2 intersection(int objectIndex ,vec3 sourcePoint, vec3 v){
    float min_t = 1.0e10;
    int object_i = -1;
    float t = 0;
    for(int i = 0 ; i < sizes.x ; i++){
        if(i == objectIndex){
            continue;
        }
        if(isSphere(objects[i])){
            t = calulateSphereIntersection(objects[i], sourcePoint, v);
        }else{
            t = calulatePlaneIntersection(objects[i], sourcePoint, v);
        }

        if(t>0 && t <= min_t){
            min_t = t;
            object_i = i;
        }
    }
    return vec2(min_t, object_i);

}

bool isInAngle(vec3 sourcePoint, int lightIndex){
    vec3 lightDirection = normalize(lightsDirection[lightIndex].xyz);
    vec3 lightToObject = normalize(sourcePoint - lightsPosition[lightIndex].xyz);
    float cosTheta =  dot(lightDirection, lightToObject);
    float theta = acos(cosTheta);
    float alpha = acos(lightsPosition[lightIndex].w);
    return theta <= alpha;
}

bool isObjectBlocked(vec3 sourcePoint, vec3 lightPos, int objectIndex){
    vec3 v = sourcePoint - lightPos;
    vec2 t = intersection(-1, lightPos, normalize(v));
    if(t.y == objectIndex){
        return false;
    }
    return true;
}

bool inSpolight(vec3 sourcePoint, int objectIndex, int lightIndex){
    return (!(isObjectBlocked(sourcePoint, lightsPosition[lightIndex].xyz, objectIndex))) && isInAngle(sourcePoint, lightIndex);
}

vec3 calcDiffuseLight(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    vec3 N = getObjectNormal(objectIndex, sourcePoint);
    vec3 L = normalize(lightsDirection[lightIndex].xyz);
    float k_s = 1;
    if(isPlane(objects[objectIndex]) && (((mod(int(1.5*sourcePoint.x),2) == mod(int(1.5*sourcePoint.y),2)) && ((sourcePoint.x>0 && sourcePoint.y>0) || (sourcePoint.x<0 && sourcePoint.y<0))) || ((mod(int(1.5*sourcePoint.x),2) != mod(int(1.5*sourcePoint.y),2) && ((sourcePoint.x<0 && sourcePoint.y>0) || (sourcePoint.x>0 && sourcePoint.y<0)))))){
        k_s = 0.5;
    }
    return clamp((k_s * objColors[objectIndex].rgb * dot(N, v) * lightsIntensity[lightIndex].rgb),0,1);
}

vec3 calcSpecularLight(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    float k_s = 0.7;
    vec3 N = getObjectNormal(objectIndex, sourcePoint);
    vec3 lightDirection = lightsDirection[lightIndex].xyz;
    vec3 R = normalize(reflect(v, N));
    float power = objColors[objectIndex].w;

    return clamp(k_s * pow(dot(v, R), power) * lightsIntensity[lightIndex].rgb,0,1);

}


vec3 calcSpotlightEfect(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    if(inSpolight(sourcePoint, objectIndex, lightIndex)){
        return calcDiffuseLight(sourcePoint, objectIndex, lightIndex, v) + calcSpecularLight(sourcePoint, objectIndex, lightIndex, v);
    }
    return vec3(0, 0, 0);
}

vec3 calcPointlightEfect(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    if(!isObjectBlocked(sourcePoint, lightsPosition[lightIndex].xyz, objectIndex)){
        return calcDiffuseLight(sourcePoint, objectIndex, lightIndex, v) + calcSpecularLight(sourcePoint, objectIndex, lightIndex, v);
    }
    return vec3(0, 0, 0);
}

vec3 calcDirectionallightEfect(vec3 sourcePoint, int objectIndex, int lightIndex, vec3 v){
    vec2 t = intersection(objectIndex, sourcePoint, -normalize(lightsDirection[lightIndex].xyz));
    if(t.y > 0 && objects[int(t.y)].w > 0){
        return vec3(0, 0, 0);
    }
    return calcDiffuseLight(sourcePoint, objectIndex, lightIndex, v) + calcSpecularLight(sourcePoint, objectIndex, lightIndex, v);

}

vec3 calculateLights(vec3 sourcePoint, int objectIndex, vec3 v){
    vec3 color = ambient.rgb * objColors[objectIndex].rgb;
    for(int i = 0; i < sizes[1]; i++){
        if(isSpotlight(lightsDirection[i])){
            color += calcSpotlightEfect(sourcePoint, objectIndex, i, v);
        }else if (isPointlight(lightsDirection[i])){
            color += calcPointlightEfect(sourcePoint, objectIndex, i, v);
        }else{
            color += calcDirectionallightEfect(sourcePoint, objectIndex, i, v);
        }
    }
    return color;
}

vec4 calculateColor(vec3 position){
    vec3 v = normalize( position  - eye.xyz);
    vec2 t = intersection(-1, position ,v);
    vec3 sourcePoint = position + t.x * v;
    if(t.y < 0){
        discard;
    }else{
        int rep = 5;
        int source_object = int(t.y);
        vec3 reflection_point = sourcePoint;
        vec3 reflection_v =v;
        vec2 t_reflection = t;
        vec3 n;
        while(rep > 0 && t_reflection.y < sizes.z ){
            n = getObjectNormal(int(t_reflection.y), reflection_point);
            vec3 u = normalize(reflect(reflection_v,n));
            vec2 tm = intersection(int(t_reflection.y), reflection_point, u);
            rep--;
            reflection_v = u;
            t_reflection = tm;
            reflection_point = reflection_point + t_reflection.x * reflection_v;
            if(t_reflection.y < 0){
                break;
            }
        }


        if(int(t_reflection.y) >= 0) {
            return vec4(calculateLights(reflection_point, int(t_reflection.y), reflection_v),1);
        }else if(t.y < sizes.z){
            return vec4(0,0,0,1);
        }else{
            return vec4(calculateLights(sourcePoint, int(t.y), v),1);
        }
    }
}

void main(){
    float y_diff = pixelSize[0]/2;
    float x_diff = pixelSize[1]/2;
    vec4 color1 = calculateColor(position0 + vec3(x_diff, 0,0));
    vec4 color2 = calculateColor(position0 - vec3(x_diff, 0,0));
    vec4 color3 = calculateColor(position0 + vec3(0, y_diff, 0));
    vec4 color4 = calculateColor(position0 - vec3(0, y_diff, 0));
    vec4 color5 = calculateColor(position0 + vec3(x_diff, y_diff,0));
    vec4 color6 = calculateColor(position0 + vec3(x_diff, -y_diff,0));
    vec4 color7 = calculateColor(position0 + vec3(-x_diff, y_diff, 0));
    vec4 color8 = calculateColor(position0 + vec3(-x_diff, -y_diff, 0));
    vec4 color9 = calculateColor(position0);
    gl_FragColor = (color1 + color2 + color3 + color4 + color5 + color6 + color7 + color8 + color9) / 9;

}
 


