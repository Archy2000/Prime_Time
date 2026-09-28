using UnityEngine;

[ExecuteInEditMode]
public class ScanlineEffect : MonoBehaviour
{
	public Shader scanlineShader;

	private Material scanlineMaterial;

	[Range(0f, 1f)]
	public float scanlineIntensity = 0.5f;

	[Range(100f, 5000f)]
	public float scanlineDensity = 800f;

	private void Start()
	{
		if (scanlineShader == null)
		{
			enabled = false;
		}
		else
		{
			scanlineMaterial = new Material(scanlineShader);
		}
	}

	private void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if (scanlineMaterial != null)
		{
			scanlineMaterial.SetFloat("_ScanlineIntensity", scanlineIntensity);
			scanlineMaterial.SetFloat("_ScanlineDensity", scanlineDensity);
			Graphics.Blit(src, dest, scanlineMaterial);
		}
		else
		{
			Graphics.Blit(src, dest);
		}
	}
}
